# plugins/review/cursor/setup.sh — surcharge Cursor : lue par ./install.sh plugin --cursor review
# (format de setup.sh, voir CLAUDE-CODE.md, Avec Cursor).
links=(                                                  # <chemin dans le plugin>  <destination>
  # les skills pr et manual les appellent par leur nom ; Claude met bin/ dans le PATH, Cursor non
  "bin/review-post             ~/.local/bin/review-post"
  "bin/review-map-html         ~/.local/bin/review-map-html"
)
