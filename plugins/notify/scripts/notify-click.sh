#!/usr/bin/env bash
# Brings the Herdr UI window or gnome-terminal tab hosting a Claude session to
# the front, and clears pending notifications. Called by claude-notify.py on click and by
# the GNOME Shell extension (claude-notify@ywicker) from its menu, through the
# ~/.local/bin/claude-notify-click link (./install.sh plugin notify).
#   --open <state.json>          focus the session, close its notification
#   --clear-session <session_id> close the pending notifications of a session
#   --clear-all                  close every pending notification
jq=$(command -v jq || echo ~/.local/bin/jq)
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/claude-notify
helper=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/claude-notify.py

gdbus_term() { gdbus call --session --dest org.gnome.Terminal "$@" 2>/dev/null; }

terminal_windows() {
  for w in $(xprop -root _NET_CLIENT_LIST 2>/dev/null | sed 's/.*# //; s/,//g'); do
    xprop -id "$w" WM_CLASS 2>/dev/null | grep -qi gnome-terminal && echo "$w"
  done
}

# _NET_ACTIVE_WINDOW client message; GNOME Shell refuses FocusApp over D-Bus
# to unprivileged callers and xdotool/wmctrl are not installed.
activate_window() {
  python3 - "$1" <<'PY'
import ctypes, sys
x = ctypes.CDLL("libX11.so.6")
x.XOpenDisplay.restype = ctypes.c_void_p
x.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
x.XDefaultRootWindow.restype = ctypes.c_ulong
x.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
x.XInternAtom.restype = ctypes.c_ulong
x.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_long, ctypes.c_void_p]
x.XFlush.argtypes = [ctypes.c_void_p]
x.XCloseDisplay.argtypes = [ctypes.c_void_p]

class ClientMessage(ctypes.Structure):
    _fields_ = [("type", ctypes.c_int), ("serial", ctypes.c_ulong), ("send_event", ctypes.c_int),
                ("display", ctypes.c_void_p), ("window", ctypes.c_ulong), ("message_type", ctypes.c_ulong),
                ("format", ctypes.c_int), ("data", ctypes.c_long * 5), ("pad", ctypes.c_long * 19)]

d = x.XOpenDisplay(None)
if not d:
    sys.exit(1)
win = int(sys.argv[1], 16)
ev = ClientMessage(type=33, send_event=1, display=d, window=win,
                   message_type=x.XInternAtom(d, b"_NET_ACTIVE_WINDOW", 0), format=32)
ev.data[0] = 2  # source: pager
x.XSendEvent(d, x.XDefaultRootWindow(d), 0, (1 << 20) | (1 << 19), ctypes.byref(ev))
x.XFlush(d)
x.XCloseDisplay(d)
PY
}

window_matching() {
  local pattern=$1 w name
  for w in $(terminal_windows); do
    name=$(xprop -id "$w" WM_NAME 2>/dev/null | sed 's/^[^=]*= "//; s/"$//')
    # shellcheck disable=SC2254
    case "$name" in $pattern) echo "$w"; return 0 ;; esac
  done
  return 1
}

# Finds the gnome-terminal tab whose title matches the glob, activates its
# window, and leaves other windows on their original tab.
find_tab() {
  local pattern=$1 w path idx start i
  # herdr retitles the tab ~100 ms after a focus: wait for it before cycling
  for i in $(seq 20); do
    if w=$(window_matching "$pattern"); then activate_window "$w"; return 0; fi
    sleep 0.05
  done
  for path in $(gdbus introspect --session --dest org.gnome.Terminal \
      --object-path /org/gnome/Terminal/window --recurse 2>/dev/null |
      grep -oE '/org/gnome/Terminal/window/[0-9]+'); do
    start=$(gdbus_term --object-path "$path" --method org.gtk.Actions.Describe active-tab |
      grep -oE '\[<[0-9]+>\]' | tr -dc 0-9)
    [ -n "$start" ] || continue
    for i in $(seq 0 63); do
      gdbus_term --object-path "$path" --method org.gtk.Actions.Activate active-tab "[<$i>]" "{}" >/dev/null
      sleep 0.05
      idx=$(gdbus_term --object-path "$path" --method org.gtk.Actions.Describe active-tab |
        grep -oE '\[<[0-9]+>\]' | tr -dc 0-9)
      [ "$idx" = "$i" ] || break
      if w=$(window_matching "$pattern"); then activate_window "$w"; return 0; fi
    done
    gdbus_term --object-path "$path" --method org.gtk.Actions.Activate active-tab "[<$start>]" "{}" >/dev/null
  done
  return 1
}

# focus_herdr <herdr_bin> <pane_id> <ws_id> <session_id>: focuses the pane;
# if it is gone, the pane now running the session (resumed elsewhere), else
# the workspace. Prints the label of the workspace focused.
focus_herdr() {
  local herdr=$1 pane_id=$2 ws_id=$3 session_id=$4 p
  if ! timeout 2 "$herdr" agent focus "$pane_id" >/dev/null 2>&1; then
    ws_id=
    [ -n "$session_id" ] && p=$(timeout 2 "$herdr" pane list 2>/dev/null |
      $jq -r --arg s "$session_id" '[.result.panes[] | select(.agent_session.value == $s)][0] // empty | "\(.pane_id) \(.workspace_id)"')
    if [ -n "$p" ] && timeout 2 "$herdr" agent focus "${p% *}" >/dev/null 2>&1; then
      ws_id=${p#* }
    elif [ -n "$3" ] && timeout 2 "$herdr" workspace focus "$3" >/dev/null 2>&1; then
      ws_id=$3
    fi
  fi
  [ -n "$ws_id" ] && timeout 2 "$herdr" workspace get "$ws_id" 2>/dev/null | $jq -r '.result.workspace.label // empty'
}

# focus_gui <ws_id>: when Herdr UI runs, brings forward its window showing the
# workspace (it follows herdr's focus), else its first window
focus_gui() {
  local id
  id=$(timeout 2 herdr-gpui window list --json 2>/dev/null |
    $jq -r --arg ws "$1" '(map(select(.workspace == $ws)) + .)[0].id // empty' 2>/dev/null)
  [ -n "$id" ] && timeout 2 herdr-gpui window focus "$id" >/dev/null 2>&1
}

# focus_session <pane_id> <herdr_bin> <ws_label> <ws_id> <session_id> <tty> <where>
focus_session() {
  local pane_id=$1 herdr=$2 ws_label=$3 ws_id=$4 session_id=$5 tty=$6 where=$7 marker w label
  if [ -n "$pane_id" ]; then
    label=$(focus_herdr "$herdr" "$pane_id" "$ws_id" "$session_id")
    focus_gui "$ws_id" && return 0
    # no workspace id (state written by an older notify.sh): keep the stored label
    [ -n "$ws_id" ] || [ -n "$label" ] || label=$ws_label
    [ -n "$label" ] && find_tab "*: $label" && return 0
  elif [ -n "$tty" ] && [ -w "$tty" ]; then
    marker="Claude Code · $where (${tty#/dev/})"
    printf '\033]2;%s\007' "$marker" > "$tty"
    sleep 0.1
    find_tab "$marker" && return 0
  fi
  w=$(terminal_windows | head -1)
  [ -n "$w" ] && activate_window "$w"
}

# clear_pending <state.json>: close the notification and forget it
clear_pending() {
  local id
  id=$($jq -r '.id // empty' "$1" 2>/dev/null)
  rm -f "$1"
  [ -n "$id" ] && python3 "$helper" close "$id" >/dev/null 2>&1
}

case "$1" in
  --open)
    f=$2
    [ -f "$f" ] || exit 0
    pane_id=$($jq -r '.pane_id // ""' "$f"); herdr=$($jq -r '.herdr // "herdr"' "$f")
    ws_label=$($jq -r '.ws_label // ""' "$f"); ws_id=$($jq -r '.ws_id // ""' "$f")
    session_id=$($jq -r '.session_id // ""' "$f"); tty=$($jq -r '.tty // ""' "$f"); where=$($jq -r '.where // ""' "$f")
    clear_pending "$f"
    focus_session "$pane_id" "$herdr" "$ws_label" "$ws_id" "$session_id" "$tty" "$where"
    ;;
  --clear-session)
    for f in "$state_dir"/*.json; do
      [ -f "$f" ] || continue
      [ "$($jq -r '.session_id // ""' "$f")" = "$2" ] && clear_pending "$f"
    done
    ;;
  --clear-all)
    for f in "$state_dir"/*.json; do [ -f "$f" ] && clear_pending "$f"; done
    ;;
  *) echo "usage: $0 --open <state.json> | --clear-session <id> | --clear-all" >&2; exit 2 ;;
esac
exit 0
