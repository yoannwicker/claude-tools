# plugins/profiles/setup.sh — ce que profiles pose hors du plugin. Lu (sourcé) par
# ./install.sh plugin profiles, qui pose, contrôle et retire ces liens (format : CLAUDE-CODE.md, Plugins).
links=(                                                  # <chemin dans le plugin>  <destination>
  "bin/claude-profile          ~/.local/bin/claude-profile"   # terminal (dans Claude, bin/ est déjà dans le PATH)
  "shell/claude-profile.sh     ~/.config/shell/claude-profile.sh"
)

on_remove() {
  echo "~/.claude-profiles/ gardé ; sans le plugin, claude part sur le profil de référence (~/.claude)"
}
