# plugins/herdr-session/setup.sh — contrôle hors du plugin. Lu (sourcé) par
# ./install.sh plugin herdr-session (format : CLAUDE-CODE.md, Plugins). Le hook que herdr pose
# lui-même dans settings.json est retiré par setup/20-herdr.sh tant que ce plugin est installé.
on_status() {
  [ -f "$HOME/.claude/hooks/herdr-agent-state.sh" ] \
    || note "script herdr absent (~/.claude/hooks/herdr-agent-state.sh) : ./setup/20-herdr.sh"
}

on_remove() {
  echo "pour garder la reprise herdr sans ce plugin : herdr integration install claude (hook dans settings.json)"
}
