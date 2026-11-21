#!/usr/bin/env bash
# Tests de cursor/convert.py et cursor/hook-adapter.py : bash cursor/tests/convert.test.sh
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo=$(dirname "$here")
fails=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

check() { # check <libellé> <commande…> : ok si la commande réussit
  local label=$1; shift
  if "$@" >/dev/null 2>&1; then printf 'ok    %s\n' "$label"; else printf 'FAIL  %s\n' "$label"; fails=$((fails + 1)); fi
}

# hook <dossier converti> <événement Cursor> <index> <JSON d'entrée> → réponse du hook converti
hook() {
  local cmd
  cmd=$(jq -r --arg e "$2" --argjson i "$3" '.hooks[$e][$i].command' "$1/hooks/hooks.json")
  printf '%s' "$4" | CURSOR_PLUGIN_ROOT=$1 bash -c "$cmd"
}

## build-brief : consigne au démarrage, garde-fou Gradle sur Shell

bb=$tmp/build-brief
python3 "$here/convert.py" "$repo/plugins/build-brief" "$bb" > "$tmp/notes"
check "build-brief : manifeste Cursor" jq -e '.name == "build-brief"' "$bb/.cursor-plugin/plugin.json"
check "build-brief : sessionStart et preToolUse sur Shell" \
  jq -e '.version == 1 and (.hooks.sessionStart | length) == 1 and .hooks.preToolUse[0].matcher == "Shell"' "$bb/hooks/hooks.json"
check "build-brief : ni setup.sh, ni tests, ni .claude-plugin copiés" \
  test ! -e "$bb/setup.sh" -a ! -e "$bb/tests" -a ! -e "$bb/.claude-plugin"
check "build-brief : aucune note" test ! -s "$tmp/notes"

fake=$tmp/bin
mkdir -p "$fake"
printf '#!/bin/sh\n[ "$1" = rewrite ] && echo "build-brief $2"\n' > "$fake/build-brief"
chmod +x "$fake/build-brief"
export PATH=$fake:$PATH
shell() { jq -nc --arg c "$1" '{conversation_id: "c", tool_name: "Shell", tool_input: {command: $c, cwd: ""}, workspace_roots: ["/tmp"]}'; }
check "build-brief : ./gradlew test refusé" \
  bash -c 'jq -e ".permission == \"deny\" and (.agent_message | test(\"build-brief ./gradlew test\"))" <<< "$1"' _ "$(hook "$bb" preToolUse 0 "$(shell './gradlew test')")"
check "build-brief : build-brief ./gradlew test laissé passer" \
  bash -c '[ "$1" = "{}" ]' _ "$(hook "$bb" preToolUse 0 "$(shell 'build-brief ./gradlew test')")"
check "build-brief : consigne en additional_context" \
  bash -c 'jq -e ".additional_context | test(\"OBLIGATOIRE\")" <<< "$1"' _ "$(hook "$bb" sessionStart 0 '{"conversation_id":"c","workspace_roots":["/tmp"]}')"

## Plugin factice : événements, dossier cursor/, chemins, garde-fous

src=$tmp/src/demo
mkdir -p "$src/.claude-plugin" "$src/hooks" "$src/skills/s1" "$src/cursor/hooks" "$src/tests"
echo '{"name":"demo","description":"d","dependencies":["x"]}' > "$src/.claude-plugin/plugin.json"
printf 'dir=${CLAUDE_SKILL_DIR} root=${CLAUDE_PLUGIN_ROOT}\n' > "$src/skills/s1/SKILL.md"
echo '{"mcpServers":{"m":{"command":"${CLAUDE_PLUGIN_ROOT}/m.sh"}}}' > "$src/.mcp.json"
cat > "$src/hooks/hooks.json" <<'EOF'
{"hooks": {"Notification": [{"hooks": [{"type": "command", "command": "true"}]}],
           "Stop": [{"hooks": [{"type": "command", "command": "echo claude-stop"}]}]}}
EOF
# Version Cursor des hooks : Claude (converti) et Cursor (gardé tel quel) mélangés.
cat > "$src/cursor/hooks/hooks.json" <<'EOF'
{"hooks": {
  "Stop": [{"hooks": [{"type": "command", "command": "jq -c \"{e: .hook_event_name}\" > \"$CLAUDE_PLUGIN_ROOT/stop.out\""}]}],
  "StopFailure": [{"hooks": [{"type": "command", "command": "jq -c \"{e: .hook_event_name}\" > \"$CLAUDE_PLUGIN_ROOT/fail.out\""}]}],
  "PreToolUse": [{"matcher": "Bash|Edit|mcp__srv__tool", "hooks": [{"type": "command", "command": "echo nope >&2; exit 2"}]}],
  "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "echo \"{\\\"decision\\\":\\\"block\\\",\\\"reason\\\":\\\"non\\\"}\""}]}],
  "afterFileEdit": [{"command": "./native.sh"}]
}}
EOF
echo 'extra' > "$src/cursor/extra.txt"
out=$tmp/out/demo
python3 "$here/convert.py" "$src" "$out" > "$tmp/notes"
check "factice : hooks de cursor/ à la place de ceux du plugin (pas de note Notification)" \
  bash -c '! grep -q Notification "$1"' _ "$tmp/notes"
check "factice : fichier de cursor/ ajouté" test -f "$out/extra.txt"
check "factice : dependencies retiré du manifeste" jq -e 'has("dependencies") | not' "$out/.cursor-plugin/plugin.json"
check "factice : \${CLAUDE_SKILL_DIR} et \${CLAUDE_PLUGIN_ROOT} remplacés" \
  grep -qx "dir=$out/skills/s1 root=$out" "$out/skills/s1/SKILL.md"
check "factice : .mcp.json devenu mcp.json, chemin remplacé" \
  jq -e --arg r "$out" '.mcpServers.m.command == ($r + "/m.sh")' "$out/mcp.json"
check "factice : Stop et StopFailure sur stop" jq -e '(.hooks.stop | length) == 2' "$out/hooks/hooks.json"
check "factice : matcher Bash|Edit|mcp__srv__tool -> Shell|Write|MCP:tool" \
  jq -e '.hooks.preToolUse[0].matcher == "Shell|Write|MCP:tool"' "$out/hooks/hooks.json"
check "factice : hook Cursor natif gardé tel quel" \
  jq -e '.hooks.afterFileEdit[0].command == "./native.sh"' "$out/hooks/hooks.json"

hook "$out" stop 0 '{"conversation_id":"c","status":"completed","workspace_roots":["/tmp"]}' >/dev/null
hook "$out" stop 1 '{"conversation_id":"c","status":"completed","workspace_roots":["/tmp"]}' >/dev/null
check "factice : fin normale -> Stop seulement" bash -c 'grep -q "\"Stop\"" "$1/stop.out" && [ ! -e "$1/fail.out" ]' _ "$out"
rm -f "$out/stop.out"
hook "$out" stop 0 '{"conversation_id":"c","status":"error","workspace_roots":["/tmp"]}' >/dev/null
hook "$out" stop 1 '{"conversation_id":"c","status":"error","workspace_roots":["/tmp"]}' >/dev/null
check "factice : erreur -> StopFailure seulement" bash -c 'grep -q StopFailure "$1/fail.out" && [ ! -e "$1/stop.out" ]' _ "$out"
check "factice : exit 2 -> deny avec stderr" \
  bash -c 'jq -e ".permission == \"deny\" and .agent_message == \"nope\"" <<< "$1"' _ "$(hook "$out" preToolUse 0 "$(shell 'ls')")"
check "factice : decision block -> continue false" \
  bash -c 'jq -e ".continue == false and .user_message == \"non\"" <<< "$1"' _ "$(hook "$out" beforeSubmitPrompt 0 '{"prompt":"p"}')"

python3 "$here/convert.py" "$src" "$out" >/dev/null
check "factice : reconversion d'un dossier généré" test -f "$out/.claude-compat/source"
mkdir -p "$tmp/mine"
check "factice : dossier non généré jamais remplacé" bash -c '! python3 "$1" "$2" "$3"' _ "$here/convert.py" "$src" "$tmp/mine"

[ $fails = 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
