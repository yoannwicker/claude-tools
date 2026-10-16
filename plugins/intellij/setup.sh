# plugins/intellij/setup.sh — ménage hors du plugin. Lu (sourcé) par ./install.sh plugin intellij
# (format : CLAUDE-CODE.md, Plugins).

# Ancien MCP intellij de scope user (ex-setup/40-mcp.sh) : à même URL, il masquerait celui du
# plugin, et ses outils ne portent pas les noms cités par la consigne du plugin.
user_mcp() { claude mcp get intellij 2>/dev/null | grep -qi 'scope: *user'; }

on_install() {
  if user_mcp; then claude mcp remove --scope user intellij; fi
}

on_status() {
  if user_mcp; then echo "MCP intellij de scope user encore présent : ./install.sh plugin intellij"; return 1; fi
}
