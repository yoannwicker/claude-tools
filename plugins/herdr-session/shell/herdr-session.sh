# ~/.config/shell/herdr-session.sh — reprise des sessions Claude dans l'app Herdr. Un terminal
# perdu (redémarrage, plantage de herdr-core) revient avec la même adresse mais un simple shell :
# si Claude y tournait (note de la session posée par le hook du plugin herdr-session), ce shell
# relance `claude --resume <id>` dans le dossier de la session.
# Seulement dans le shell racine du terminal, lancé seul par herdr-core (argv = le shell), et si
# le terminal est celui de la note (created_ms). La note est retirée avant la reprise.
# Chargé par ~/.bash_aliases (lien posé par ./install.sh plugin herdr-session).
# Doc : CLAUDE-CODE.md du dépôt claude-tools, plugin « herdr-session ».
__herdr_session_resume() {
    local f t sid cwd
    f=${XDG_STATE_HOME:-$HOME/.local/state}/herdr-session/$(basename "${HC_TERMINAL_SOCKET:-default.sock}" .sock)/$HC_TERMINAL_ID.json
    [ -f "$f" ] && command -v hc >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 0
    t=$(timeout 5 hc get "$HC_TERMINAL_ID" --json 2>/dev/null) || return 0
    jq -e --argjson pid "$$" --slurpfile n "$f" \
        '.pid == $pid and (.argv | length) == 1 and .created_ms == $n[0].created_ms' <<<"$t" >/dev/null 2>&1 \
        || return 0
    sid=$(jq -r .session_id "$f"); cwd=$(jq -r '.cwd // empty' "$f")
    rm -f "$f"
    [ -n "$sid" ] || return 0
    [ -n "$cwd" ] && [ -d "$cwd" ] && cd "$cwd"
    echo "herdr-session : reprise de la session Claude $sid"
    claude --resume "$sid"
}
case $- in
    *i*) [ -n "${HC_TERMINAL_ID:-}" ] && __herdr_session_resume ;;
esac
