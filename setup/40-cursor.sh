#!/usr/bin/env bash
# Cursor (cursor-agent) : branche la status line de Claude (~/.claude/statusline-command.sh, posée par
# ./install.sh link) dans ~/.cursor/cli-config.json. Ce fichier est l'état de Cursor (modèle choisi,
# permissions…) : on n'y change que la clé statusLine, sans le versionner. Sans cursor-agent : rien.
set -eu
if ! command -v cursor-agent >/dev/null 2>&1; then
  echo "cursor-agent absent : rien à faire"
  exit 0
fi
command -v jq >/dev/null 2>&1 || { echo "jq absent : status line Cursor non branchée"; exit 1; }
cfg=${CURSOR_CONFIG_DIR:-$HOME/.cursor}/cli-config.json
# Cursor lance la commande sans shell : ni préfixe VAR=…, ni ~ (d'où env et le chemin absolu).
want=$(jq -nc --arg c "env STATUSLINE_AGENT=cursor bash $HOME/.claude/statusline-command.sh" \
  '{type: "command", command: $c, padding: 0, updateIntervalMs: 10000}')
[ -f "$cfg" ] || { mkdir -p "$(dirname "$cfg")"; echo '{"version":1}' > "$cfg"; }
if jq -e --argjson w "$want" '.statusLine == $w' "$cfg" >/dev/null; then
  echo "status line Cursor : à jour"
else
  tmp=$(mktemp)
  jq --argjson w "$want" '.statusLine = $w' "$cfg" > "$tmp" && cat "$tmp" > "$cfg" && rm -f "$tmp"
  echo "status line Cursor : branchée dans ${cfg/#$HOME/\~}"
fi
