# plugins/gh-watch/setup.sh — commande gh-watch (supervision des watchers) dans ~/.local/bin.
# Lu (sourcé) par ./install.sh plugin gh-watch (format : CLAUDE-CODE.md, Plugins), et
# installé d'office avec review et git-tidy (dépendance déclarée dans leur plugin.json).
links=(                                       # <chemin dans le plugin>  <destination>
  "bin/gh-watch  ~/.local/bin/gh-watch"
)
