# ~/.config/shell/claude-profile.sh — `claude` lancé par `claude-profile run`, qui garde le profil courant
# mais relance la session quand /profile <nom> demande un autre profil. Chargé par ~/.bash_aliases.
# Doc : CLAUDE-CODE.md du dépôt claude-tools, plugin « profiles ».
claude() {
    if command -v claude-profile >/dev/null 2>&1; then claude-profile run "$@"; else command claude "$@"; fi
}
