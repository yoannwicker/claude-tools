# ~/.bash_aliases — sourcé par le .bashrc (Ubuntu par défaut). Versionné dans claude-tools.
# Ne fait que charger les outils shell de ~/.config/shell/ (voir SHELL.md).
for f in ~/.config/shell/*.sh; do
    [ -r "$f" ] && . "$f"
done
unset f
