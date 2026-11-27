# ~/.config/shell/claude-profile.sh — `claude` lancé par `claude-profile run` : sur le profil par
# défaut (sinon le profil de référence), ou le profil courant dans une session de profil, et relancé quand
# /profile <nom> demande un autre profil. `cursor-agent` (et `agent`) lancé par `claude-profile cursor` :
# sur le profil donné en premier argument, sinon celui du projet, sinon le profil par défaut ; ses
# commandes de gestion (login, update, plugin…) vont droit au vrai cursor-agent.
# Chargé par ~/.bash_aliases (lien posé par ./install.sh plugin profiles).
# Doc : CLAUDE-CODE.md du dépôt claude-tools, plugin « profiles ».
claude() {
    if command -v claude-profile >/dev/null 2>&1; then claude-profile run "$@"; else command claude "$@"; fi
}
# Session sur la connexion /login au lieu du jeton longue durée : connecteurs claude.ai (Drive, Docs…).
claude-login() { CLAUDE_PROFILE_LOGIN=1 claude "$@"; }
cursor-agent() {
    if ! command -v claude-profile >/dev/null 2>&1; then command cursor-agent "$@"; return; fi
    case "${1:-}" in
        persist|install-shell-integration|uninstall-shell-integration|login|logout|mcp|plugin|worker|\
        status|whoami|models|team|bedrock|about|update|generate-rule|rule|help|-h|--help|-v|--version)
            command cursor-agent "$@" ;;
        *)  claude-profile cursor "$@" ;;
    esac
}
agent() { cursor-agent "$@"; }
