# plugins/review/cursor/setup.sh — surcharge Cursor : lue par ./install.sh plugin --cursor review
# (format de setup.sh, voir CLAUDE-CODE.md, Avec Cursor).
links=(                                                  # <chemin dans le plugin>  <destination>
  # le skill pr l'appelle par son nom ; Claude met bin/ dans le PATH, Cursor non
  "bin/review-post             ~/.local/bin/review-post"
)
