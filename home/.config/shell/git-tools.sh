# ~/.config/shell/git-tools.sh — outils git/GitHub du terminal (hors Claude).
# Chargé par ~/.bash_aliases. Doc : SHELL.md du dépôt claude-tools.

alias gprs='gh pr list --search "sort:updated-desc"'    # PR ouvertes, récentes d'abord
alias gprr='gh pr list --search "review-requested:@me"' # PR à relire

# gpr : enveloppe du script ~/.local/bin/gpr pour faire le cd final dans le shell courant
# (un script ne peut pas changer le dossier de son appelant).
gpr() {
    local f d rc
    f=$(mktemp) || return 1
    GPR_CD_FILE=$f command gpr "$@"; rc=$?
    d=$(<"$f"); rm -f "$f"
    [[ -n "$d" ]] && cd "$d"
    return $rc
}
