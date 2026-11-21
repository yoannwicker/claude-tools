#!/usr/bin/env bash
# Tests de la version Cursor de notify (cursor/scripts/cursor-watch.sh), avec un faux herdr et un
# faux claude-notify.py : bash plugins/notify/tests/cursor-watch.test.sh
set -u
plugin=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fails=0
tmp=$(mktemp -d)
trap 'pkill -f "$tmp/" 2>/dev/null; rm -rf "$tmp"' EXIT

check() { # check <libellé> <commande…>
  local label=$1; shift
  if "$@" >/dev/null 2>&1; then printf 'ok    %s\n' "$label"; else printf 'FAIL  %s\n' "$label"; fails=$((fails + 1)); fi
}

# Scripts du plugin tels qu'installés pour Cursor : scripts/ et, par-dessus, cursor/scripts/.
mkdir -p "$tmp/scripts" "$tmp/bin" "$tmp/state"
cp "$plugin"/scripts/notify.sh "$plugin"/cursor/scripts/cursor-watch.sh "$tmp/scripts/"
cat > "$tmp/scripts/claude-notify.py" <<EOF
import json, sys
open("$tmp/shown", "a").write(json.dumps(json.load(sys.stdin)) + "\n")
EOF
cat > "$tmp/scripts/notify-click.sh" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$tmp/cleared"
EOF

# Faux herdr : l'état courant de l'agent du pane (« agent état ») est dans $tmp/states.cur, les
# états suivants dans $tmp/states, une ligne chacun. agent wait les consomme jusqu'au premier
# état demandé et échoue quand il n'y en a plus. « état! » : état bref, l'agent est déjà
# reparti quand on relit son état (l'état courant redevient working).
cat > "$tmp/bin/herdr" <<'HERDR'
#!/usr/bin/env bash
f=$FAKE_HERDR_STATES
case "$1 $2" in
  "agent get")
    read -r agent status < "$f.cur" 2>/dev/null && [ -n "$agent" ] || exit 1
    printf '{"result":{"agent":{"agent":"%s","agent_status":"%s"}}}\n' "$agent" "$status" ;;
  "agent wait")
    [ -n "${FAKE_HERDR_HANG:-}" ] && exec sleep 30
    shift 3; want=" "
    while [ $# -gt 0 ]; do [ "$1" = --until ] && want+="$2 "; shift 2; done
    while read -r agent status < "$f" 2>/dev/null && [ -n "$agent" ]; do
      sed -i 1d "$f"
      case "$status" in
        *!) status=${status%!}; echo "$agent working" > "$f.cur" ;;
        *) echo "$agent $status" > "$f.cur" ;;
      esac
      case "$want" in *" $status "*)
        printf '{"result":{"agent":{"agent":"%s","agent_status":"%s"}}}\n' "$agent" "$status"; exit 0 ;;
      esac
    done
    : > "$f.cur"
    echo '{"error":{"code":"agent_not_found"}}'; exit 1 ;;
  "pane get") echo '{"result":{"pane":{"focused":false,"agent":"cursor"}}}' ;;
  "workspace get") echo '{"result":{"workspace":{"label":"ws","number":1}}}' ;;
esac
HERDR
chmod +x "$tmp/bin/herdr" "$tmp/scripts/notify-click.sh"

export HERDR_BIN_PATH=$tmp/bin/herdr HERDR_PANE_ID=w1:p1 HERDR_WORKSPACE_ID=w1
export XDG_STATE_HOME=$tmp/state FAKE_HERDR_STATES=$tmp/states
export CURSOR_WATCH_DETECT_TRIES=2 CURSOR_WATCH_SETTLE=0
input='{"session_id":"s1","cwd":"/tmp","hook_event_name":"SessionStart"}'
pidfile=$tmp/state/claude-notify/cursor-watch-w1_p1.pid

# wait_lines <fichier> <n> : le fichier a n lignes (notify.sh affiche en arrière-plan), 5 s au plus
wait_lines() { for _ in $(seq 50); do [ "$(wc -l < "$1" 2>/dev/null)" = "$2" ] && return 0; sleep 0.1; done; return 1; }

# Un tour terminé ; puis un tour avec un idle bref, une validation demandée, terminé.
echo "cursor idle" > "$tmp/states.cur"
printf '%s\n' "cursor working" "cursor idle" "cursor working" "cursor idle!" "cursor blocked" \
  "cursor working" "cursor done" > "$tmp/states"
echo "$input" | bash "$tmp/scripts/cursor-watch.sh" start
check "3 notifications : fin, permission, fin (rien pour l'idle bref)" wait_lines "$tmp/shown" 3
check "l'observateur finit quand l'agent disparaît" \
  bash -c 'sleep 0.5; [ ! -e "$1" ] && ! pgrep -f "$2 watch"' _ "$pidfile" "$tmp/scripts/cursor-watch.sh"
check "fin de tour -> Stop" bash -c 'sed -n 1p "$1" | jq -e ".event == \"Stop\" and (.title | test(\"Travail terminé\"))"' _ "$tmp/shown"
check "blocked -> permission, critique" \
  bash -c 'sed -n 2p "$1" | jq -e ".event == \"Notification\" and .urgency == \"critical\" and .session_id == \"s1\""' _ "$tmp/shown"
check "done -> Stop, pane herdr gardé pour le clic" \
  bash -c 'sed -n 3p "$1" | jq -e ".event == \"Stop\" and .pane_id == \"w1:p1\""' _ "$tmp/shown"
check "agent reparti -> notifications de la session effacées (3 fois)" \
  bash -c '[ "$(grep -c -- "--clear-session s1" "$1")" = 3 ]' _ "$tmp/cleared"

rm -f "$tmp/shown"
echo "claude idle" > "$tmp/states.cur"
printf '%s\n' "claude working" "claude idle" > "$tmp/states"
echo "$input" | bash "$tmp/scripts/cursor-watch.sh" start
check "agent autre que Cursor : rien" bash -c 'sleep 3; [ ! -e "$1" ] && [ ! -e "$2" ]' _ "$tmp/shown" "$pidfile"

# stop : l'observateur, bloqué dans herdr agent wait, est arrêté avec lui.
echo "cursor idle" > "$tmp/states.cur"
echo "$input" | FAKE_HERDR_HANG=1 bash "$tmp/scripts/cursor-watch.sh" start
sleep 0.5
pid=$(cat "$pidfile" 2>/dev/null)
echo '{}' | bash "$tmp/scripts/cursor-watch.sh" stop
sleep 0.3
check "stop arrête l'observateur et son herdr agent wait" \
  bash -c '[ -n "$1" ] && ! kill -0 "$1" 2>/dev/null && ! pgrep -g "$1"' _ "$pid"

unset HERDR_PANE_ID
echo "$input" | bash "$tmp/scripts/cursor-watch.sh" start
check "hors herdr : rien de lancé" test ! -e "$pidfile"

[ $fails = 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
