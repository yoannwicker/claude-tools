# ~/.config/shell/claude-profile.sh — `claude` lancé par `claude-profile run` : sur le profil par
# défaut (sinon le profil de référence), ou le profil courant dans une session de profil, et relancé quand
# /profile <nom> demande un autre profil. Chargé par ~/.bash_aliases.
# Doc : CLAUDE-CODE.md du dépôt claude-tools, plugin « profiles ».
claude() {
    if command -v claude-profile >/dev/null 2>&1; then claude-profile run "$@"; else command claude "$@"; fi
}
