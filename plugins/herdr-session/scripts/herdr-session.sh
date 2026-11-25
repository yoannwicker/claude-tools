#!/usr/bin/env bash
# herdr-session.sh start|end — hooks SessionStart / SessionEnd du plugin herdr-session (JSON du
# hook sur stdin). Signale la session Claude à l'interface herdr qui l'héberge, pour qu'elle
# soit reprise (claude --resume) après un redémarrage :
#   - app Herdr (terminal de herdr-core, HC_TERMINAL_ID posé) : note la session du terminal dans
#     ~/.local/state/herdr-session/<core>/<terminal>.json ; ~/.config/shell/herdr-session.sh la
#     reprend dans le shell que herdr-core redonne au terminal perdu. SessionEnd efface la note
#     seulement sur une sortie voulue (/exit, ctrl+d, /logout : rien à reprendre) ; un arrêt par
#     signal (extinction de la machine, terminal tué : reason « other ») la garde pour la reprise.
#   - herdr en terminal (HERDR_PANE_ID posé) : passe la main au script de l'intégration Claude
#     de herdr (~/.claude/hooks/herdr-agent-state.sh), qui le dit au serveur herdr.
# Rien sous Cursor (CURSOR_VERSION) ni pour un sous-agent.
set -u
[ -z "${CURSOR_VERSION:-}" ] || exit 0
in=$(cat)
jq=$(command -v jq || echo ~/.local/bin/jq)
[ "$($jq -r '.agent_id // empty' <<<"$in" 2>/dev/null)" = "" ] || exit 0

if [ -n "${HC_TERMINAL_ID:-}" ]; then
  command -v hc >/dev/null 2>&1 || exit 0
  core=$(basename "${HC_TERMINAL_SOCKET:-default.sock}" .sock)
  dir=${XDG_STATE_HOME:-$HOME/.local/state}/herdr-session/$core
  f=$dir/$HC_TERMINAL_ID.json
  sid=$($jq -r '.session_id // empty' <<<"$in")
  [ -n "$sid" ] || exit 0
  case ${1:-} in
    start)
      # created_ms : le même terminal après sa perte (même adresse) ; une adresse reprise par un
      # nouveau terminal en a un autre
      created=$(timeout 5 hc get "$HC_TERMINAL_ID" --json 2>/dev/null | $jq -r '.created_ms // empty')
      [ -n "$created" ] || exit 0
      mkdir -p "$dir"
      $jq -n --arg session_id "$sid" --arg cwd "$($jq -r '.cwd // empty' <<<"$in")" \
        --argjson created_ms "$created" '$ARGS.named' > "$f.tmp" && mv "$f.tmp" "$f" ;;
    end)
      case $($jq -r '.reason // empty' <<<"$in") in prompt_input_exit|logout) ;; *) exit 0 ;; esac
      [ -f "$f" ] && [ "$($jq -r .session_id "$f" 2>/dev/null)" = "$sid" ] && rm -f "$f" ;;
  esac
  exit 0
fi

if [ "${1:-}" = start ] && [ -n "${HERDR_PANE_ID:-}" ] && [ -f "$HOME/.claude/hooks/herdr-agent-state.sh" ]; then
  bash "$HOME/.claude/hooks/herdr-agent-state.sh" session <<<"$in"
fi
exit 0
