# plugins/git-nav/cursor/setup.sh — surcharge Cursor : lue par ./install.sh plugin --cursor git-nav
# (format de setup.sh, voir CLAUDE-CODE.md, Avec Cursor).
links=(                                                  # <chemin dans le plugin>  <destination>
  # le skill worktree l'appelle par son nom ; Claude met bin/ dans le PATH, Cursor non
  "bin/worktree-scan           ~/.local/bin/worktree-scan"
)
