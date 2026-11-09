#!/usr/bin/env bash
# Tests de review-watch : bash plugins/review/tests/review-watch.test.sh
# Faux gh, claude et herdr (arrêté : analyse en fond) ; config, état et clone temporaires ;
# notifications écrites dans un fichier. Rien n'est lancé ni publié pour de vrai.
set -u
bin=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/review-watch
export LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/gh-watch/lib
fails=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export FAKE=$tmp HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_STATE_HOME=$tmp/state \
  XDG_CACHE_HOME=$tmp/cache REVIEW_WATCH_NOTIFY_LOG=$tmp/notifs \
  GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME" "$tmp/fakebin"

cat > "$tmp/fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "api user") echo '{"login": "moi"}' ;;
  "api notifications"*) cat "$FAKE/notifs.json" ;;
  "api graphql")  # mes PR : board.watched (requête sur l'entrée standard)
    if [ "${3:-}" = --input ]; then cat "$FAKE/mine.json"
    else n=$(sed -n 's/.*n=\([0-9]*\).*/\1/p' <<<"$*"); cat "$FAKE/pr-$n.json"; fi ;;
  "pr view")
    if [[ "$*" == *"--json author"* ]]; then echo '{"author": {"login": "autre"}}'
    else echo "{\"title\": \"PR $3\", \"url\": \"https://github.com/o/r/pull/$3\", \"state\": \"OPEN\",
                \"headRefName\": \"feat-x\", \"headRefOid\": \"abc\"}"; fi ;;
  "repo view") echo o/r ;;
  *) echo "faux gh : appel inattendu $*" >&2; exit 1 ;;
esac
EOF
cat > "$tmp/fakebin/herdr" <<'EOF'
#!/usr/bin/env bash
# arrêté (status), mais les panes notés dans l'état existent : session herdr déjà ouverte
case "$1 $2" in
  "agent get") echo '{"result": {}}' ;;
  "agent prompt") printf '%s\n' "$3 $4" >> "$FAKE/herdr-prompts"; exit "${HERDR_PROMPT_RC:-0}" ;;
  *) exit 1 ;;
esac
EOF
cat > "$tmp/fakebin/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$PWD $*" >> "$FAKE/claude-calls"
EOF
printf '#!/usr/bin/env bash\necho inactive\nexit 3\n' > "$tmp/fakebin/systemctl"
chmod +x "$tmp/fakebin"/*
export PATH=$tmp/fakebin:$PATH

check() { # check <libellé> <attendu> <obtenu>
  if [ "$2" = "$3" ]; then printf 'ok    %s\n' "$1"
  else printf 'FAIL  %s (attendu : %s, obtenu : %s)\n' "$1" "$2" "$3"; fails=$((fails + 1)); fi
}
ago() { date -u -d "${T0:-now} $1 ago" +%Y-%m-%dT%H:%M:%SZ; }
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)  # dates fixes : une même review garde sa date d'un passage à l'autre
notif() { # notif <n>… : notifications review_requested sur o/r
  jq -n --arg t "$(ago '1 minute')" '[$ARGS.positional[] | {reason: "review_requested",
    updated_at: $t, repository: {full_name: "o/r"},
    subject: {type: "PullRequest", url: "https://api.github.com/repos/o/r/pulls/\(.)"}}]' --args "$@" \
    > "$tmp/notifs.json"
}
pr() { # pr <n> <demandée il y a> [ma review il y a]
  jq -n --arg n "$1" --arg asked "$(ago "$2")" --arg mine "${3:+$(ago "$3")}" \
    '{data: {repository: {pullRequest: {number: ($n | tonumber), title: "PR \($n)", url: "u\($n)",
      state: "OPEN", author: {login: "autre"}, headRefName: "feat-x", headRefOid: "abc",
      timelineItems: {nodes: [{createdAt: $asked, requestedReviewer: {__typename: "User", login: "moi"}}]},
      reviews: {nodes: (if $mine == "" then [] else [{state: "COMMENTED", submittedAt: $mine}] end)}}}}}' \
    > "$tmp/pr-$1.json"
}
mine() { # mine <n>:<il y a>:<état>:<fils non résolus du relecteur>[:<message>] … (nœuds de gh-watch board)
  local a n t s c m specs=()
  for a in "$@"; do IFS=: read -r n t s c m <<<"$a"; specs+=("$n|$(ago "$t")|$s|$c|$m"); done
  jq -n '{data: {viewer: {login: "moi"}, search: {nodes: [$ARGS.positional[] | split("|") as [$n, $at, $s, $c, $m]
    | {id: "o/r#\($n)", number: ($n | tonumber), title: "Ma PR", url: "m", isDraft: false, createdAt: $at,
       author: {login: "moi"}, repository: {nameWithOwner: "o/r"}, headRefName: "feat-x",
       reviewRequests: {nodes: []}, timelineItems: {nodes: []}, comments: {nodes: []},
       latestOpinionatedReviews: {nodes: (if $s == "COMMENTED" then [] else
         [{author: {__typename: "User", login: "relecteur"}, state: $s, submittedAt: $at}] end)},
       reviews: {nodes: [{author: {__typename: "User", login: "relecteur"}, state: $s, submittedAt: $at, body: $m}]},
       reviewThreads: {nodes: [range($c | tonumber) | {isResolved: false,
         first: {nodes: [{author: {login: "relecteur"}, createdAt: $at}]},
         last: {nodes: [{author: {login: "relecteur"}, createdAt: $at}]}}]},
       commits: {nodes: []}}]}}}' --args "${specs[@]}"
}
notifs() { [ -f "$tmp/notifs" ] && jq -r .title "$tmp/notifs" | paste -sd'|' || echo; }

# Clone o/r avec la branche distante feat-x
git init -q "$tmp/clone" && git -C "$tmp/clone" commit -q --allow-empty -m init
git -C "$tmp/clone" remote add origin git@github.com:o/r.git
git -C "$tmp/clone" update-ref refs/remotes/origin/feat-x HEAD

# 1. Premier passage : ce qui est déjà là est seulement enregistré
notif 1; pr 1 "1 hour"; mine > "$tmp/mine.json"
out=$("$bin" poll)
check "état initial : rien lancé ni notifié" "1:" "$(grep -c 'déjà là' <<<"$out"):$(notifs)"

# 2. Dépôt non listé : notification dont le clic lance /review:pr
notif 1 2; pr 2 "1 minute"
"$bin" poll >/dev/null
check "non listé → notification" "Revue demandée : o/r#2" "$(notifs)"
check "clic → review-watch launch" "launch o/r#2 review" "$(jq -r '.action[2:] | join(" ")' "$tmp/notifs")"
check "PR déjà traitée → rien de plus" 1 "$("$bin" poll >/dev/null; wc -l < "$tmp/notifs")"

# 3. Déjà relue depuis la demande → rien
rm -f "$tmp/notifs"; notif 3; pr 3 "10 minutes" "2 minutes"
"$bin" poll >/dev/null
check "déjà relue → rien" "" "$(notifs)"

# 4. /review:pr-auto on : analyse en fond (herdr arrêté) puis notification « prête »
(cd "$tmp/clone" && "$bin" auto . on review >/dev/null && "$bin" auto . on feedback >/dev/null)
check "auto on → config" "auto auto $tmp/clone" \
  "$(jq -r '.repos["o/r"] | "\(.review) \(.feedback) \(.path)"' "$XDG_CONFIG_HOME/claude-tools/review-watch.json")"
notif 4; pr 4 "1 minute"
"$bin" poll >/dev/null
for _ in $(seq 50); do [ -s "$tmp/notifs" ] && break; sleep 0.1; done
check "analyse en fond : /review:pr --prepare dans le clone" "$tmp/clone -p /review:pr 4 --prepare" \
  "$(cut -d' ' -f1-5 "$tmp/claude-calls")"
check "notification prête, clic → resume" "Revue prête à valider : o/r#4|resume o/r#4 review" \
  "$(jq -r '"\(.title)|\(.action[2:] | join(" "))"' "$tmp/notifs")"
check "session prête" ready "$(jq -r '.sessions["o/r#4:review"].status' "$XDG_STATE_HOME/claude-tools/review-watch/state.json")"

# 5. Retours sur ma PR : trop récents → attendre ; avec commentaires → /review:feedback dans un worktree
rm -f "$tmp/notifs" "$tmp/claude-calls"; echo '[]' > "$tmp/notifs.json"
mine "9:1 minute:COMMENTED:2" > "$tmp/mine.json"
"$bin" poll >/dev/null
check "review trop récente → attendre" "" "$(cat "$tmp/claude-calls" 2>/dev/null)"
mine "9:10 minutes:COMMENTED:2" > "$tmp/mine.json"
"$bin" poll >/dev/null
for _ in $(seq 50); do [ -s "$tmp/notifs" ] && break; sleep 0.1; done
wt=$XDG_CACHE_HOME/claude-tools/review-worktrees/clone/feat-x
check "feedback : worktree de la branche, /review:feedback --prepare" "$wt -p /review:feedback 9 --prepare" \
  "$(cut -d' ' -f1-5 "$tmp/claude-calls")"
check "worktree sur feat-x, suivi d'origin" "feat-x origin/feat-x" \
  "$(git -C "$wt" rev-parse --abbrev-ref HEAD) $(git -C "$wt" rev-parse --abbrev-ref '@{u}')"

# 6. Approuvée sans commentaire → simple notification
rm -f "$tmp/notifs" "$tmp/claude-calls"
mine "9:10 minutes:COMMENTED:2" "10:10 minutes:APPROVED:0" > "$tmp/mine.json"
"$bin" poll >/dev/null
check "approuvée → notification, rien lancé" "PR approuvée : o/r#10|" "$(notifs)|$(cat "$tmp/claude-calls" 2>/dev/null)"
check "historique : notifié, approuvée sans retour" "notifié approuvée sans retour à traiter" \
  "$(jq -r '[.history[] | select(.key == "o/r#10:feedback")][-1] | "\(.action) \(.detail)"' \
     "$XDG_STATE_HOME/claude-tools/review-watch/state.json")"

# 6b. Même calcul que gh-watch board : un message à traiter lance, « LGTM 👍 » non ;
# une approbation de plus sur des retours déjà vus : simple notification
rm -f "$tmp/notifs" "$tmp/claude-calls"
mine "12:10 minutes:APPROVED:0:Approuvée, mais renomme la méthode stp" "13:10 minutes:APPROVED:0:LGTM 👍" > "$tmp/mine.json"
"$bin" poll >/dev/null
for _ in $(seq 50); do [ -s "$tmp/claude-calls" ] && break; sleep 0.1; done
check "approbation avec un message à traiter → /review:feedback" "-p /review:feedback 12 --prepare" \
  "$(cut -d' ' -f2-5 "$tmp/claude-calls")"
check "approbation « LGTM 👍 » → notification seulement" 1 "$(grep -c 'PR approuvée : o/r#13' <(notifs | tr '|' '\n'))"
rm -f "$tmp/notifs" "$tmp/claude-calls"
mine "9:10 minutes:COMMENTED:2" > "$tmp/mine.json"  # retours de 9 déjà traités (5.)
jq --arg at "$(ago '8 minutes')" '.data.search.nodes[0].reviews.nodes += [{author: {__typename: "User", login: "autre"},
  state: "APPROVED", submittedAt: $at, body: ""}]' "$tmp/mine.json" > "$tmp/m" && mv "$tmp/m" "$tmp/mine.json"
"$bin" poll >/dev/null
check "approbation sur des retours déjà vus → notification, rien lancé" "PR approuvée : o/r#9|" \
  "$(notifs)|$(cat "$tmp/claude-calls" 2>/dev/null)"

# 7. off : retour au mode par défaut ; mode off : ignoré
(cd "$tmp/clone" && "$bin" auto . off review >/dev/null && "$bin" auto . off feedback >/dev/null)
check "auto off → dépôt retiré de la config" null "$(jq -c '.repos["o/r"]' "$XDG_CONFIG_HOME/claude-tools/review-watch.json")"
"$bin" add o/r --review off >/dev/null
rm -f "$tmp/notifs"; notif 11; pr 11 "1 minute"; mine > "$tmp/mine.json"
check "mode off → ignoré" "ignoré|" "$("$bin" poll | sed 's/.*: //')|$(notifs)"
check "repos --json" "o/r off notify" "$("$bin" repos --json | jq -r '.[0] | "\(.repo) \(.review) \(.feedback)"')"

# 8. Intervalle du scan : drop-in du timer, retiré au retour à 5 min
dropin=$XDG_CONFIG_HOME/systemd/user/review-watch.timer.d/interval.conf
"$bin" interval 15 >/dev/null
check "interval 15 → config et drop-in" "15 OnUnitActiveSec=15min" \
  "$(jq -r .interval "$XDG_CONFIG_HOME/claude-tools/review-watch.json") $(tail -1 "$dropin")"
check "status donne l'intervalle" 1 "$("$bin" status | grep -c 'toutes les 15 min')"
"$bin" interval 5 >/dev/null
check "interval 5 → défaut, drop-in retiré" "null absent" \
  "$(jq -r .interval "$XDG_CONFIG_HOME/claude-tools/review-watch.json") $([ -e "$dropin" ] && echo présent || echo absent)"

# 9. Session herdr déjà ouverte sur la PR : nouveaux retours envoyés dans le pane
"$bin" add o/r --feedback auto >/dev/null
st=$XDG_STATE_HOME/claude-tools/review-watch/state.json
jq '.sessions["o/r#30:feedback"] = {mode: "herdr", pane: "p30", dir: "d"}' "$st" > "$st.new" && mv "$st.new" "$st"
mine "30:10 minutes:COMMENTED:2" > "$tmp/mine.json"
rm -f "$tmp/notifs" "$tmp/claude-calls" "$tmp/herdr-prompts"
"$bin" poll >/dev/null
check "session ouverte → message dans le pane, rien de lancé" "p30 review-watch : nouveaux retours sur la PR #30|" \
  "$(sed 's/ (.*//' "$tmp/herdr-prompts")|$(cat "$tmp/claude-calls" 2>/dev/null)"
body() { jq -r '"\(.body | sub(".*: "; "")) \(.urgency)"' "$tmp/notifs"; }
check "notification : message envoyé" "message envoyé normal" "$(body)"
mine "30:6 minutes:COMMENTED:1" > "$tmp/mine.json"
rm -f "$tmp/notifs"
HERDR_PROMPT_RC=1 "$bin" poll >/dev/null
check "agent en attente d'une réponse → notification critique" "occupée, message non envoyé critical" "$(body)"

# 10. L'auteur d'une PR que j'ai relue a réagi (answered) : pris en charge pour le rattrapage
# de gh-watch (événement review), jamais cherché par poll
check "answered → review, pour gh-watch board" review "$("$bin" status --json | jq -r .board.answered)"

# 11. auto pour tous les dépôts d'un propriétaire (owner/*) ou pour tous (*) ; le réglage
# propre d'un dépôt l'emporte
cfgf=$XDG_CONFIG_HOME/claude-tools/review-watch.json
modes() { "$bin" repos --json | jq -r --arg r "$1" '.[] | select(.repo == $r) | "\(.review) \(.feedback)"'; }
"$bin" remove o/r >/dev/null
"$bin" auto 'o/*' on review >/dev/null
"$bin" add o/r --feedback off >/dev/null
check "auto o/* on → o/r en auto par son propriétaire" "auto off" "$(modes o/r)"
check "status : o/* listé" "o/*  review=auto feedback=notify  (tous les dépôts de o)" "$("$bin" status | grep -F 'o/*' | sed 's/^ *//')"
check "gh-watch board : mode de o/r par o/*" auto "$(python3 - "$("$bin" status --json)" <<'PY'
import json, os, sys
sys.path.insert(0, os.path.join(os.environ["LIB"]))
import board
print(board.repo_entry(json.loads(sys.argv[1])["repos"], "O/x").get("review"))
PY
)"
"$bin" auto 'o/*' off review >/dev/null
check "auto o/* off → retiré de la config" null "$(jq -c '.repos["o/*"]' "$cfgf")"
"$bin" auto '*' on >/dev/null
check "auto * on → défaut en auto" "auto auto" "$(jq -r '.default | "\(.review) \(.feedback)"' "$cfgf")"
check "auto * : réglage propre de o/r gardé" "auto off" "$(modes o/r)"
"$bin" auto '*' off feedback >/dev/null
check "auto * off feedback → défaut du watcher" "auto notify" "$("$bin" status --json | jq -r '.default | "\(.review) \(.feedback)"')"
check "cible invalide refusée" 1 "$("$bin" auto o on 2>&1 | grep -c 'owner/\*')"

[ "$fails" = 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
