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
  # `add` recopie le chemin absolu du dépôt dans ~/.claude/settings.json (propre à la machine ;
  # régénéré depuis profiles/ de toute façon) : on l'en retire, la marketplace reste connue via
  # known_marketplaces.json.
  settings=$HOME/.claude/settings.json
  if command -v jq >/dev/null 2>&1 && jq -e '.extraKnownMarketplaces."claude-tools"' "$settings" >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq 'del(.extraKnownMarketplaces."claude-tools") | if .extraKnownMarketplaces == {} then del(.extraKnownMarketplaces) else . end' "$settings" > "$tmp"
    cat "$tmp" > "$settings" && rm -f "$tmp"
  fi
fi

for p in pr-comments intellij profiles; do
  if claude plugin list 2>/dev/null | grep -q "$p@claude-tools"; then
    claude plugin update "$p@claude-tools"
  else
    claude plugin install "$p@claude-tools"
  fi
done

# Commande claude-profile du plugin profiles, aussi pour le terminal (dans Claude, bin/ du plugin
# est déjà dans le PATH de l'outil Bash).
mkdir -p "$HOME/.local/bin"
ln -sfn "$repo/plugins/profiles/bin/claude-profile" "$HOME/.local/bin/claude-profile"
# ~/.claude/settings.json : celui du profil par défaut (vidal si aucun n'est encore choisi).
"$repo/plugins/profiles/bin/claude-profile" default >/dev/null 2>&1 || "$repo/plugins/profiles/bin/claude-profile" default vidal
# Ancien nom de la commande (profile), lien laissé par une installation précédente.
[ -L "$HOME/.local/bin/profile" ] && [ "$(readlink "$HOME/.local/bin/profile")" = "$repo/plugins/profiles/bin/profile" ] && rm "$HOME/.local/bin/profile"

# Ancien MCP intellij de scope user (ex-setup/40-mcp.sh) : à même URL, il masquerait celui
# du plugin intellij, et ses outils ne portent pas les noms cités par la consigne du plugin.
if claude mcp get intellij 2>/dev/null | grep -qi 'scope: *user'; then
  claude mcp remove --scope user intellij
fi
