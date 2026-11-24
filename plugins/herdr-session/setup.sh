# plugins/herdr-session/setup.sh — ce que herdr-session pose hors du plugin. Lu (sourcé) par
# ./install.sh plugin herdr-session (format : CLAUDE-CODE.md, Plugins). Le hook que herdr pose
# lui-même dans settings.json est retiré par setup/20-herdr.sh tant que ce plugin est installé.
links=(                                                  # <chemin dans le plugin>  <destination>
  "shell/herdr-session.sh      ~/.config/shell/herdr-session.sh"   # reprise dans l'app Herdr
)

on_status() {
  if command -v herdr >/dev/null 2>&1 && [ ! -f "$HOME/.claude/hooks/herdr-agent-state.sh" ]; then
    note "script herdr absent (~/.claude/hooks/herdr-agent-state.sh) : ./setup/20-herdr.sh"
  fi
}

on_remove() {
  echo "pour garder la reprise herdr (terminal) sans ce plugin : herdr integration install claude (hook dans settings.json)"
}
