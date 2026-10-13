# git-tools.sh — fonctions communes à gpr et gbr (sourcé par les scripts, pas exécuté).
# Les scripts définissent PROG (nom de la commande) pour les messages.

die() { echo "${PROG:-git-tools} : $*" >&2; exit 1; }

in_repo() { git rev-parse --git-dir >/dev/null 2>&1 || die "pas dans un dépôt git."; }

# wt_of <branche> : chemin du worktree où <branche> est checkoutée (vide sinon).
wt_of() {
    git worktree list --porcelain | awk -v b="branch refs/heads/$1" '
        /^worktree / { p = substr($0, 10) }
        $0 == b      { print p; exit }'
}

# wt_add <dossier> <branche locale> [refspec] : réutilise le worktree déjà ouvert sur
# <branche>, sinon le crée dans <racine du dépôt principal>/.claude/worktrees/<dossier>
# (même emplacement que les worktrees de Claude : vu par /worktree, accepté par
# EnterWorktree). Fetch de origin <refspec> s'il est donné. Seul le chemin va sur stdout.
wt_add() {
    local name=$1 branch=$2 refspec=${3:-} path common root
    path=$(wt_of "$branch")
    if [[ -n "$path" ]]; then echo "$path"; return; fi

    common=$(git rev-parse --path-format=absolute --git-common-dir) || exit 1
    root=$(dirname "$common")
    path="$root/.claude/worktrees/$name"
    {
        if [[ -n "$refspec" ]]; then git fetch origin "$refspec" || exit 1; fi
        if ! git -C "$root" check-ignore -q .claude/worktrees/x; then
            mkdir -p "$common/info"
            echo ".claude/worktrees/" >> "$common/info/exclude"
        fi
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            git worktree add "$path" "$branch" || exit 1
        else
            git worktree add --track -b "$branch" "$path" "origin/$branch" || exit 1
        fi
        if [[ -f "$path/mise.toml" || -f "$path/.mise.toml" ]] && command -v mise >/dev/null; then
            (cd "$path" && mise trust)
        fi
    } >&2
    echo "$path"
}

# pick <invite> <choix>… : menu select (sur stderr) ; écrit le choix, rien si abandon.
pick() {
    local PS3="$1 : " choice
    shift
    select choice in "$@"; do
        [[ -n "$choice" ]] && { echo "$choice"; return; }
    done
}

# place <branche locale> <dossier de worktree> <refspec> <commande de checkout…> :
# demande où se placer (branche courante, worktree, rester ici). Worktree choisi : son
# chemin est écrit dans $GIT_TOOLS_CD_FILE (la fonction shell y fait le cd), sinon affiché.
place() {
    local branch=$1 name=$2 refspec=$3
    shift 3
    local dir="" wt wt_label="Worktree" opts choice
    if [[ "$(git rev-parse --abbrev-ref HEAD)" == "$branch" ]]; then
        echo "Déjà sur $branch ici."
    else
        wt=$(wt_of "$branch")
        [[ -n "$wt" ]] && wt_label="Worktree existant ($wt)"
        if [[ -n "$(git status --porcelain)" ]]; then
            echo "Travail local non commité ici :"
            git status --short
            opts=("$wt_label" "Branche courante (attention : modifs en cours)" "Rester ici")
        else
            opts=("Branche courante" "$wt_label" "Rester ici")
        fi
        choice=$(pick "Se placer sur $branch" "${opts[@]}")
        case "$choice" in
            Worktree*) dir=$(wt_add "$name" "$branch" "$refspec") || exit 1 ;;
            Branche*)  "$@" || exit 1 ;;
        esac
    fi

    if [[ -n "$dir" ]]; then
        if [[ -n "${GIT_TOOLS_CD_FILE:-}" ]]; then echo "$dir" > "$GIT_TOOLS_CD_FILE"
        else echo "cd $dir"
        fi
    fi
    echo "→ $(git -C "${dir:-.}" rev-parse --abbrev-ref HEAD) · ${dir:-$PWD}"
}
