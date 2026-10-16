# plugins/notify/setup.sh — ce que notify pose hors du plugin. Lu (sourcé) par
# ./install.sh plugin notify (format : CLAUDE-CODE.md, Plugins).
links=(                                                  # <chemin dans le plugin>  <destination>
  # chemin stable pour l'extension GNOME claude-notify@ywicker (hors de Claude, pas de ${CLAUDE_PLUGIN_ROOT})
  "scripts/notify-click.sh     ~/.local/bin/claude-notify-click"
)

# L'extension GNOME (pastille) est liée par ./install.sh link et activée par setup/30-gnome.sh.
on_status() {
  command -v gnome-extensions >/dev/null 2>&1 || { note "pas de GNOME Shell : notifications sans pastille"; return 0; }
  gnome-extensions info claude-notify@ywicker 2>/dev/null | grep -q ACTIVE \
    || note "extension GNOME claude-notify@ywicker inactive : ./install.sh link && ./setup/30-gnome.sh"
}
