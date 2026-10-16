# plugins/git-nav/setup.sh — ce que git-nav pose hors du plugin. Lu (sourcé) par
# ./install.sh plugin git-nav, qui pose, contrôle et retire ces liens (format : CLAUDE-CODE.md, Plugins).
links=(                                                  # <chemin dans le plugin>  <destination>
  "bin/gpr                     ~/.local/bin/gpr"           # terminal (dans Claude, bin/ est déjà dans le PATH)
  "bin/gbr                     ~/.local/bin/gbr"
  "shell/git-tools.sh          ~/.config/shell/git-tools.sh"
)
