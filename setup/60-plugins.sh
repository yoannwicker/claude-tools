#!/usr/bin/env bash
# Plugins Claude Code de plugins/ : marketplace locale « claude-tools » (ce dépôt) déclarée,
# puis chaque plugin installé s'il manque, ou mis à jour depuis le dépôt sinon.
set -eu
command -v claude >/dev/null 2>&1 || { echo "claude absent : plugins ignorés"; exit 0; }
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if claude plugin marketplace list 2>/dev/null | grep -q 'claude-tools'; then
  claude plugin marketplace update claude-tools
else
  claude plugin marketplace add "$repo"
  # `add` recopie le chemin absolu du dépôt dans ~/.claude/settings.json (versionné, propre à
  # la machine) : on l'en retire, la marketplace reste connue via known_marketplaces.json.
  settings=$HOME/.claude/settings.json
  if command -v jq >/dev/null 2>&1 && jq -e '.extraKnownMarketplaces."claude-tools"' "$settings" >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq 'del(.extraKnownMarketplaces."claude-tools") | if .extraKnownMarketplaces == {} then del(.extraKnownMarketplaces) else . end' "$settings" > "$tmp"
    cat "$tmp" > "$settings" && rm -f "$tmp"
  fi
fi

for p in pr-comments; do
  if claude plugin list 2>/dev/null | grep -q "$p@claude-tools"; then
    claude plugin update "$p@claude-tools"
  else
    claude plugin install "$p@claude-tools"
  fi
done
