#!/usr/bin/env bash
# Desktop notification for Claude Code hooks; reads the hook JSON on stdin.
# Hands the notification to claude-notify.py (detached, so the hook returns
# at once); UserPromptSubmit clears what is pending for the session instead.
jq=$(command -v jq || echo ~/.local/bin/jq)
in=$(cat)
event=$($jq -r '.hook_event_name // empty' <<<"$in")
type=$($jq -r '.notification_type // empty' <<<"$in")
msg=$($jq -r '.message // .error // empty' <<<"$in")
session_id=$($jq -r '.session_id // empty' <<<"$in")
where=$(basename "$($jq -r '.cwd // empty' <<<"$in")")
urgency=normal
ws_label=
agent=

if [ "$event" = UserPromptSubmit ]; then
  [ -n "$session_id" ] && setsid -f bash ~/.claude/notify-click.sh --clear-session "$session_id" </dev/null >/dev/null 2>&1
  exit 0
fi

# tty of the gnome-terminal tab hosting this session: the highest ancestor
# that still has one (the herdr client under herdr, the shell otherwise)
tty=
p=$PPID
for _ in $(seq 20); do
  [ -z "$p" ] || [ "$p" = 1 ] && break
  read -r pp t <<<"$(ps -o ppid=,tty= -p "$p" 2>/dev/null)"
  case "$t" in pts/*) tty=/dev/$t ;; esac
  p=$pp
done

# Inside herdr, name the workspace and the agent session instead of the dir
if [ -n "$HERDR_PANE_ID" ]; then
  herdr=${HERDR_BIN_PATH:-herdr}
  wsjson=$(timeout 2 "$herdr" workspace get "$HERDR_WORKSPACE_ID" 2>/dev/null)
  ws_label=$($jq -r '.result.workspace.label // empty' <<<"$wsjson" 2>/dev/null)
  ws=$($jq -r '.result.workspace | select(.label) | "\(.label) (#\(.number))"' <<<"$wsjson" 2>/dev/null)
  pane=$(timeout 2 "$herdr" pane get "$HERDR_PANE_ID" 2>/dev/null)
  agent=$($jq -r '.result.pane | [.agent, .terminal_title_stripped] | map(select(. // "" != "")) | join(" · ")' <<<"$pane" 2>/dev/null)
  where=${ws:-$where}

  # Stay quiet when I am already looking at this pane: shown in herdr and
  # the active X11 window is a terminal (xprop cannot tell which one).
  if [ "$($jq -r '.result.pane.focused' <<<"$pane" 2>/dev/null)" = true ]; then
    win=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{print $NF}')
    xprop -id "$win" WM_CLASS 2>/dev/null | grep -qi terminal && exit 0
  fi
fi

# Permission prompts and pending questions block the session: keep them on
# screen (critical). The rest is a transient banner kept in the GNOME list.
case "$event:$type" in
  Stop:*)                         title="✅ Travail terminé" ;;
  StopFailure:*)                  title="❌ Erreur" ;;
  Notification:permission_prompt) title="🔐 Permission demandée";     urgency=critical ;;
  Notification:elicitation_dialog)
                                  title="❓ Claude attend ta réponse"; urgency=critical ;;
  # idle_prompt repeats the Stop notification a minute later; auth_success
  # needs no action
  Notification:idle_prompt|Notification:auth_success) exit 0 ;;
  *)                              title="🔔 Claude Code" ;;
esac

body=$(printf '%s\n%s' "$agent" "$msg" | sed '/^$/d')
[ "$event" = Stop ] && [ -z "$body" ] && body="C'est fini"
$jq -n --arg title "$title${where:+ · $where}" --arg body "$body" --arg urgency "$urgency" \
  --arg pane_id "$HERDR_PANE_ID" --arg herdr "${HERDR_BIN_PATH:-herdr}" --arg ws_label "$ws_label" \
  --arg tty "$tty" --arg where "$where" --arg session_id "$session_id" --arg event "$event" \
  '$ARGS.named' |
  setsid -f python3 ~/.claude/claude-notify.py show >/dev/null 2>&1
