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

for p in pr-comments intellij profiles git-nav notify; do
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
# Anciens scripts de notification de home/.claude/ (liés par install.sh avant le plugin notify),
# dans ~/.claude et dans les dossiers de profil générés (qui en reprenaient la cible).
for n in notify.sh notify-click.sh claude-notify.py; do
  for d in "$HOME/.claude" "$HOME"/.claude-profiles/*; do
    [ -L "$d/$n" ] && [ "$(readlink "$d/$n")" = "$repo/home/.claude/$n" ] && rm "$d/$n"
  done
done
# Dossiers de profil régénérés depuis profiles/*.json (réglages à jour, liens morts retirés).
"$repo/plugins/profiles/bin/claude-profile" generate --all
# ~/.claude/settings.json : celui du profil par défaut (vidal si aucun n'est encore choisi).
"$repo/plugins/profiles/bin/claude-profile" default >/dev/null 2>&1 || "$repo/plugins/profiles/bin/claude-profile" default vidal
# Ancien nom de la commande (profile), lien laissé par une installation précédente.
[ -L "$HOME/.local/bin/profile" ] && [ "$(readlink "$HOME/.local/bin/profile")" = "$repo/plugins/profiles/bin/profile" ] && rm "$HOME/.local/bin/profile"

# Commandes gpr et gbr du plugin git-nav, aussi pour le terminal (remplace les anciens liens
# vers home/.local/bin/).
for c in gpr gbr; do
  ln -sfn "$repo/plugins/git-nav/bin/$c" "$HOME/.local/bin/$c"
done
# Script de clic du plugin notify à un chemin stable, pour l'extension GNOME claude-notify@ywicker
# (hors de Claude, pas de ${CLAUDE_PLUGIN_ROOT} pour trouver le plugin).
ln -sfn "$repo/plugins/notify/scripts/notify-click.sh" "$HOME/.local/bin/claude-notify-click"
# Anciens skills /pr, /br, /worktree de home/.claude/skills/ (liés par install.sh avant
# git-nav) : sans ce ménage, ils doubleraient ceux du plugin, dans tous les profils
# (~/.claude-profiles/*/skills est un lien vers ~/.claude/skills).
for s in pr br worktree; do
  d=$HOME/.claude/skills/$s
  [ -d "$d" ] || continue
  for f in "$d"/*; do
    [ -L "$f" ] && [ "$(readlink "$f")" = "$repo/home/.claude/skills/$s/${f##*/}" ] && rm "$f"
  done
  rmdir "$d" 2>/dev/null || true
done

# Ancien MCP intellij de scope user (ex-setup/40-mcp.sh) : à même URL, il masquerait celui
# du plugin intellij, et ses outils ne portent pas les noms cités par la consigne du plugin.
if claude mcp get intellij 2>/dev/null | grep -qi 'scope: *user'; then
  claude mcp remove --scope user intellij
fi
