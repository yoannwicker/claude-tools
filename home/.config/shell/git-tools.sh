# ~/.config/shell/git-tools.sh — outils git/GitHub du terminal (hors Claude).
# Chargé par ~/.bash_aliases. Doc : CLAUDE-CODE.md (plugin git-nav) du dépôt claude-tools.

alias gprs='gh pr list --search "sort:updated-desc"'    # PR ouvertes, récentes d'abord
alias gprr='gh pr list --search "review-requested:@me"' # PR à relire
alias gbrs='command gbr list'                           # branches, dernier commit d'abord

# _git_tools_run <commande> <args…> : lance le script et fait le cd final dans le shell
# courant (un script ne peut pas changer le dossier de son appelant) : le script écrit le
# dossier du worktree choisi dans $GIT_TOOLS_CD_FILE.
_git_tools_run() {
    local f d rc
    f=$(mktemp) || return 1
    GIT_TOOLS_CD_FILE=$f command "$@"; rc=$?
    d=$(<"$f"); rm -f "$f"
    [[ -n "$d" ]] && cd "$d"
    return $rc
}

gpr() { _git_tools_run gpr "$@"; }
gbr() { _git_tools_run gbr "$@"; }
