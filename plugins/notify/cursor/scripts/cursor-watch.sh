#!/usr/bin/env bash
# Version Cursor du plugin notify (plugins/notify/cursor/, voir CLAUDE-CODE.md, notify) : le CLI
# Cursor ne lance pas les hooks stop ni beforeSubmitPrompt, alors on suit l'agent par herdr.
#   cursor-watch.sh start|stop   hooks sessionStart / sessionEnd (JSON au format Claude sur stdin)
#   cursor-watch.sh watch <session> <cwd>   l'observateur, détaché par start
# Hors herdr (pas de HERDR_PANE_ID : IDE, autre terminal), rien : pas de quoi suivre l'agent.
# L'observateur suit les changements d'état de l'agent du pane (herdr agent wait) et passe à
# notify.sh un événement au format Claude : Stop pour une fin de tour (working -> idle ou done,
# si l'état tient), Notification permission_prompt quand il attend une validation (blocked),
# UserPromptSubmit quand il repart (working), pour effacer ce qui reste en attente. Il s'arrête
# quand le pane n'a plus d'agent Cursor, ou à sessionEnd.
here=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
jq=$(command -v jq || echo ~/.local/bin/jq)
herdr=${HERDR_BIN_PATH:-herdr}
state=${XDG_STATE_HOME:-$HOME/.local/state}/claude-notify
[ -n "$HERDR_PANE_ID" ] || { cat >/dev/null; exit 0; }
STATES="idle working blocked done unknown"
pidfile=$state/cursor-watch-${HERDR_PANE_ID//[^A-Za-z0-9]/_}.pid

stop() {
  local pid
  pid=$(cat "$pidfile" 2>/dev/null) || return 0
  rm -f "$pidfile"
  # Groupe entier (setsid) : l'observateur et le herdr agent wait qu'il attend.
  [ -n "$pid" ] && kill -- "-$pid" 2>/dev/null
  return 0
}

notify() { # notify <événement> [<notification_type> <message>]
  $jq -n --arg e "$1" --arg t "${2:-}" --arg m "${3:-}" --arg s "$session_id" --arg c "$cwd" \
    '{hook_event_name: $e, notification_type: $t, message: $m, session_id: $s, cwd: $c}' |
    bash "$here/notify.sh"
}

current() { # état de l'agent Cursor du pane, échec s'il n'y en a pas
  local out
  out=$("$herdr" agent get "$HERDR_PANE_ID" 2>/dev/null) || return 1
  [ "$($jq -r '.result.agent.agent // empty' <<<"$out")" = cursor ] || return 1
  $jq -r '.result.agent.agent_status' <<<"$out"
}

wait_for() { # wait_for <état>… : état atteint par l'agent Cursor du pane, échec sinon
  local args=() s out
  for s in "$@"; do args+=(--until "$s"); done
  out=$("$herdr" agent wait "$HERDR_PANE_ID" "${args[@]}" 2>/dev/null) || return 1
  [ "$($jq -r '.result.agent.agent // empty' <<<"$out")" = cursor ] || return 1
  $jq -r '.result.agent.agent_status' <<<"$out"
}

case "${1:-}" in
  start)
    in=$(cat)
    stop
    mkdir -p "$state"
    setsid -f bash "${BASH_SOURCE[0]}" watch \
      "$($jq -r '.session_id // empty' <<<"$in")" "$($jq -r '.cwd // empty' <<<"$in")" \
      </dev/null >/dev/null 2>&1
    ;;
  stop)
    cat >/dev/null
    stop
    ;;
  watch)
    session_id=$2 cwd=$3
    echo $$ > "$pidfile"
    # sessionStart arrive au lancement de cursor-agent, avant que herdr ne l'ait reconnu.
    for _ in $(seq "${CURSOR_WATCH_DETECT_TRIES:-30}"); do
      current >/dev/null && break
      sleep 1
    done
    prev=$(current) || prev=unknown
    while status=$(wait_for $(printf '%s\n' $STATES | grep -vx -- "$prev")); do
      # herdr lit l'écran : un idle ou done bref peut passer pendant le travail. Une fin de tour
      # n'est annoncée que si l'état tient.
      if [ "$prev" = working ] && { [ "$status" = idle ] || [ "$status" = done ]; }; then
        sleep "${CURSOR_WATCH_SETTLE:-2}"
        status=$(current) || break
        [ "$status" = "$prev" ] && continue
      fi
      case "$prev>$status" in
        *">working")                 notify UserPromptSubmit ;;
        *">blocked")                 notify Notification permission_prompt "Cursor attend une validation" ;;
        "working>idle"|"working>done") notify Stop ;;
      esac
      prev=$status
    done
    [ "$(cat "$pidfile" 2>/dev/null)" = $$ ] && rm -f "$pidfile"
    ;;
  *)
    echo "usage : cursor-watch.sh start|stop|watch <session> <cwd>" >&2; exit 2 ;;
esac
exit 0
