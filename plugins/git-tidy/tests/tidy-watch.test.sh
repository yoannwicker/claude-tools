#!/usr/bin/env bash
# Tests de tidy-watch : bash plugins/git-tidy/tests/tidy-watch.test.sh
# Faux gh, claude et herdr (arrêté : analyse en fond) ; config, état et clone temporaires ;
# notifications écrites dans un fichier. Rien n'est lancé ni publié pour de vrai.
set -u
bin=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/tidy-watch
fails=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export FAKE=$tmp HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_STATE_HOME=$tmp/state \
  XDG_CACHE_HOME=$tmp/cache TIDY_WATCH_NOTIFY_LOG=$tmp/notifs \
  GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME" "$tmp/fakebin"
cfg=$XDG_CONFIG_HOME/claude-tools/git-tidy.json

cat > "$tmp/fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "api user") echo '{"login": "moi"}' ;;
  "api graphql") cat "$FAKE/mine.json" ;;
  "pr view") echo "{\"title\": \"PR $3\", \"url\": \"https://github.com/o/r/pull/$3\", \"state\": \"OPEN\",
                \"headRefName\": \"feat-x\", \"headRefOid\": \"abc\"}" ;;
  "repo view") echo o/r ;;
  *) echo "faux gh : appel inattendu $*" >&2; exit 1 ;;
esac
EOF
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/fakebin/herdr"
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
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)
notifs() { [ -f "$tmp/notifs" ] && jq -r .title "$tmp/notifs" | paste -sd'|' || echo; }
calls() { cat "$tmp/claude-calls" 2>/dev/null; }
wait_notif() { for _ in $(seq 50); do [ -s "$tmp/notifs" ] && break; sleep 0.1; done; }

# appr <n>[d][t<auteur du dernier message d'un fil non résolu>]=<relecteur>:<état>:<il y a>,…
appr() {
  local specs=() a
  for a in "$@"; do
    local head=${a%%=*} revs=${a#*=} out="" r thread=""
    [[ $head == *t* ]] && thread=${head#*t} && head=${head%%t*}
    IFS=, read -ra rs <<<"$revs"
    for r in "${rs[@]}"; do
      IFS=: read -r who st t <<<"$r"
      out+="$who|$st|$(ago "$t");"
    done
    specs+=("${head%d}#$([[ $head == *d ]] && echo true || echo false)#$out#$thread")
  done
  # nœuds de gh-watch board (board.watched)
  jq -n '{data: {viewer: {login: "moi"}, search: {nodes: [$ARGS.positional[] | split("#") as [$n, $d, $r, $t]
    | ($r | split(";") | map(select(. != "") | split("|")
        | {author: {__typename: "User", login: .[0]}, state: .[1], submittedAt: .[2], body: ""})) as $revs
    | {id: "o/r#\($n)", number: ($n | tonumber), title: "Ma PR \($n)", url: "m\($n)", isDraft: ($d == "true"),
       createdAt: "2026-01-01T00:00:00Z", author: {login: "moi"}, repository: {nameWithOwner: "o/r"},
       reviewRequests: {nodes: []}, timelineItems: {nodes: []}, comments: {nodes: []}, commits: {nodes: []},
       latestOpinionatedReviews: {nodes: $revs}, reviews: {nodes: $revs},
       reviewThreads: {nodes: (if $t == "" then [] else [{isResolved: false,
         first: {nodes: [{author: {login: "b"}, createdAt: "2026-01-01T00:00:00Z"}]},
         last: {nodes: [{author: {login: $t}, createdAt: "2026-01-01T00:00:00Z"}]}}] end)}}]}}}' \
    --args "${specs[@]}"
}

# Clone o/r avec la branche distante feat-x
git init -q "$tmp/clone" && git -C "$tmp/clone" commit -q --allow-empty -m init
git -C "$tmp/clone" remote add origin git@github.com:o/r.git
git -C "$tmp/clone" update-ref refs/remotes/origin/feat-x HEAD
wt=$XDG_CACHE_HOME/claude-tools/tidy-worktrees/clone/feat-x

# 1. Premier passage : ce qui est déjà là est seulement enregistré ; off par défaut
appr "20=a:APPROVED:10 minutes,b:APPROVED:9 minutes" > "$tmp/mine.json"
out=$("$bin" poll)
check "état initial : rien lancé" "1|" "$(grep -c 'déjà là' <<<"$out")|$(calls)"
appr "19=a:APPROVED:10 minutes,b:APPROVED:9 minutes" > "$tmp/mine.json"
check "rien de réglé : off" "o/r#19 (pr_approved, off) : ignoré|" "$("$bin" poll)|$(calls)"

# 2. /git-tidy:approved-auto on : section watcher de git-tidy.json (le reste : réglages des skills)
mkdir -p "$(dirname "$cfg")" && echo '{"repos": {"o/r": {"reviewers": ["x"]}}}' > "$cfg"
(cd "$tmp/clone" && "$bin" auto . on >/dev/null)
check "auto on → section watcher de git-tidy.json, le reste gardé" "auto $tmp/clone x" \
  "$(jq -r '"\(.watcher.repos["o/r"] | "\(.on_pr_approved) \(.path)") \(.repos["o/r"].reviewers[0])"' "$cfg")"

# 3. Pas assez d'approbations, changements demandés, brouillon, trop récente → rien
appr "21=a:APPROVED:10 minutes" "22=a:APPROVED:10 minutes,b:CHANGES_REQUESTED:9 minutes" \
  "23d=a:APPROVED:10 minutes,b:APPROVED:9 minutes" "24=a:APPROVED:10 minutes,b:APPROVED:1 minute" > "$tmp/mine.json"
"$bin" poll >/dev/null
check "1 approbation, changements demandés, brouillon, trop récente → rien" "|" "$(calls)|$(notifs)"

# 4. Fil de review en attente de ma réponse → attendre ; répondu → lancer
appr "25tb=a:APPROVED:10 minutes,b:APPROVED:9 minutes" > "$tmp/mine.json"
out=$("$bin" poll)
check "fil non résolu d'un autre → attend" "1|" "$(grep -c 'o/r#25 (pr_approved) : 1 fil' <<<"$out")|$(calls)"
"$bin" poll >/dev/null  # toujours en attente : pas une deuxième entrée d'historique
appr "25tmoi=a:APPROVED:10 minutes,b:APPROVED:9 minutes" > "$tmp/mine.json"
"$bin" poll >/dev/null
wait_notif
check "fil répondu → /git-tidy:ready --prepare dans le worktree de la branche" \
  "$wt -p /git-tidy:ready 25 --prepare" "$(cut -d' ' -f1-5 "$tmp/claude-calls")"
check "notification « prête »" "Préparation au merge prête à valider : o/r#25" "$(notifs)"
st=$XDG_STATE_HOME/claude-tools/tidy-watch/state.json
check "historique : en attente (une fois), puis lancé" "en attente|lancé" \
  "$(jq -r '[.history[] | select(.key == "o/r#25:pr_approved") | .action] | join("|")' "$st")"

# 5. Approbation de plus → pas relancé
rm -f "$tmp/notifs" "$tmp/claude-calls"
appr "25=a:APPROVED:10 minutes,b:APPROVED:9 minutes,c:APPROVED:8 minutes" > "$tmp/mine.json"
"$bin" poll >/dev/null
check "approbation de plus → pas relancé" "" "$(calls)"

# 6. Seuil et réglages par dépôt
(cd "$tmp/clone" && "$bin" approvals . 3 >/dev/null)
appr "26=a:APPROVED:10 minutes,b:APPROVED:9 minutes" > "$tmp/mine.json"
"$bin" poll >/dev/null
check "approvals 3 → 2 ne suffisent pas" "" "$(calls)"
(cd "$tmp/clone" && "$bin" set . validation_status "Recette" >/dev/null && "$bin" set . test_env "https://recette/{branch}" >/dev/null)
check "repos --json : approvals et réglages" "3 Recette https://recette/{branch}" \
  "$("$bin" repos --json | jq -r '.[0] | "\(.approvals) \(.validation_status) \(.test_env)"')"
check "réglages des skills hors de la section watcher" "3 Recette" \
  "$(jq -r '.repos["o/r"] | "\(.approvals) \(.validation_status)"' "$cfg")"
"$bin" approvals '*' 4 >/dev/null
check "approvals * → default de git-tidy.json (lu par les skills)" 4 "$(jq -r .default.approvals "$cfg")"
"$bin" approvals '*' default >/dev/null
check "set sans valeur : réglage et provenance" "o/r : validation_status = Recette (dépôt)" \
  "$(cd "$tmp/clone" && "$bin" set . validation_status)"
(cd "$tmp/clone" && "$bin" approvals . default >/dev/null && "$bin" set . validation_status default >/dev/null)
check "default → valeur par défaut" "o/r : validation_status = En validation (défaut)|2" \
  "$(cd "$tmp/clone" && "$bin" set . validation_status)|$("$bin" repos --json | jq -r '.[0].approvals')"
(cd "$tmp/clone" && "$bin" auto . off >/dev/null)
check "auto off : réglages gardés" "null https://recette/{branch}" \
  "$(jq -r '"\(.watcher.repos["o/r"].on_pr_approved) \(.repos["o/r"].test_env)"' "$cfg")"

# skip et launch --at (gh-watch skip / launch) : date retenue, historique, sans reculer
st=$XDG_STATE_HOME/claude-tools/tidy-watch/state.json
"$bin" skip o/r#77 pr_approved --at 2026-11-04T10:00:00Z >/dev/null
check "skip : date retenue et historique « refusé »" "2026-11-04T10:00:00Z refusé" \
  "$(jq -r '"\(.pr_approved["o/r#77"]) \(.history[-1].action)"' "$st")"
"$bin" skip o/r#77 pr_approved --at 2026-11-01T10:00:00Z >/dev/null
check "skip : une date plus ancienne ne recule pas" "2026-11-04T10:00:00Z" "$(jq -r '.pr_approved["o/r#77"]' "$st")"
check "skip sans --at → erreur" 2 "$("$bin" skip o/r#77 pr_approved >/dev/null 2>&1; echo $?)"
"$bin" launch o/r#78 pr_approved --at 2026-11-04T12:00:00Z >/dev/null 2>&1
check "launch --at : date retenue, historique « lancé » à la main" "2026-11-04T12:00:00Z lancé à la main" \
  "$(jq -r '"\(.pr_approved["o/r#78"]) \(.history[-1].action) \(.history[-1].detail | split(" :")[0])"' "$st")"

# launch --background : analyse en fond même quand herdr tourne
rm -f "$tmp/claude-calls" "$tmp/notifs"
printf '#!/usr/bin/env bash\n[ "$1 $2" = "status server" ] && echo "status: running" && exit 0\nexit 1\n' > "$tmp/fakebin/herdr"
"$bin" launch o/r#79 pr_approved --background >/dev/null 2>&1
for _ in $(seq 50); do grep -q ' 79 --prepare' "$tmp/claude-calls" 2>/dev/null && break; sleep 0.1; done
check "launch --background avec herdr en marche → analyse en fond (--prepare)" "-p /git-tidy:ready 79 --prepare" \
  "$(grep ' 79 --prepare' "$tmp/claude-calls" | cut -d' ' -f2-5)"
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/fakebin/herdr"

# Rattrapage quotidien (gh-watch set board_auto on) : à la fin du premier poll de la journée,
# gh-watch board --all --missed --json en détaché, une notification, une fois par jour
export GH_WATCH_CONFIG=$tmp/gh-watch.json GH_WATCH_STATE=$tmp/gh-watch/state.json GH_WATCH_BIN=$tmp/fakebin/gh-watch
cat > "$GH_WATCH_BIN" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$FAKE/gh-watch-calls"
row() { echo "{\"repo\": \"o/r\", \"n\": $1, \"title\": \"PR $1\", \"state\": \"$2\", \"short\": \"$3\",
  \"event_at\": \"2026-11-04T10:00:00Z\", \"watch\": {\"watcher\": \"tidy-watch\", \"kind\": \"$4\"}}"; }
echo "{\"prs\": [$(row 40 approved "approuvée 2/2" approved), $(row 41 feedback "retours (1 fil)" feedback)]}"
EOF
chmod +x "$GH_WATCH_BIN"
catchup=$tmp/gh-watch/catchup.json
appr > "$tmp/mine.json"
rm -f "$tmp/notifs" "$tmp/gh-watch-calls"
"$bin" poll >/dev/null
check "board_auto absent → pas de rattrapage" "absent" "$([ -e "$catchup" ] && echo présent || echo absent)"
echo '{"board_auto": "on"}' > "$GH_WATCH_CONFIG"
check "board_auto on → rattrapage lancé au poll" 1 "$("$bin" poll | grep -c 'rattrapage du jour lancé')"
for _ in $(seq 50); do [ -s "$tmp/notifs" ] && break; sleep 0.1; done
check "gh-watch board --all --missed --json" "board --all --missed --json" "$(cat "$tmp/gh-watch-calls")"
check "une notification « 2 actions manquées »" "2 actions manquées|_catchup_open" \
  "$(jq -r '"\(.title)|\(.action[2])"' "$tmp/notifs")"
check "rattrapage retenu : jour, nombre, lignes" "$(date +%F) tidy-watch 2 41:feedback" \
  "$(jq -r '"\(.day) \(.by) \(.count) \(.rows[1].n):\(.rows[1].kind)"' "$catchup")"
"$bin" poll >/dev/null
check "deuxième poll du jour → pas relancé" 0 "$("$bin" poll | grep -c rattrapage)"
jq '.day = "2026-01-01"' "$catchup" > "$tmp/c" && mv "$tmp/c" "$catchup"
check "nouveau jour → relancé" 1 "$("$bin" poll | grep -c 'rattrapage du jour lancé')"
for _ in $(seq 50); do [ "$(jq -r .finished "$catchup")" != null ] && break; sleep 0.1; done
# Clic : liste des manquées dans un workspace herdr s'il tourne, sinon un terminal
cat > "$tmp/fakebin/herdr" <<'EOF'
#!/usr/bin/env bash
echo "herdr $*" >> "$FAKE/herdr.log"
case "$1 $2" in
  "status server") echo "status: running" ;;
  "workspace create") echo '{"result": {"root_pane": {"pane_id": "w9:p1"}}}' ;;
esac
EOF
"$bin" _catchup_open
check "clic, herdr en marche → workspace" "herdr workspace create --cwd $HOME --label manquées --focus" \
  "$(grep 'workspace create' "$tmp/herdr.log")"
check "… qui ouvre la liste des manquées" 1 \
  "$(grep -c "^herdr pane run w9:p1 exec sh -c '$GH_WATCH_BIN board --all --missed -i ||" "$tmp/herdr.log")"
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/fakebin/herdr"
printf '#!/usr/bin/env bash\necho "$*" > "$FAKE/term"\n' > "$tmp/fakebin/term" && chmod +x "$tmp/fakebin/term"
jq --arg t "$tmp/fakebin/term" '.watcher.terminal = $t' "$cfg" > "$tmp/c" && mv "$tmp/c" "$cfg"
"$bin" _catchup_open
for _ in $(seq 50); do [ -s "$tmp/term" ] && break; sleep 0.1; done
check "clic sans herdr → terminal de la config" "$GH_WATCH_BIN board --all --missed -i" "$(cat "$tmp/term")"

# Ancienne config : réglages du watcher au premier niveau de git-tidy.json → section watcher
export XDG_CONFIG_HOME=$tmp/config2 XDG_STATE_HOME=$tmp/state2
cfg=$XDG_CONFIG_HOME/claude-tools/git-tidy.json
mkdir -p "$(dirname "$cfg")"
echo '{"repos": {"o/r": {"approved": "auto", "path": "/x", "approvals": 3, "test_env": "e"}},
  "default": {"approved": "notify", "approvals": 2}, "interval": 9}' > "$cfg"
"$bin" status >/dev/null
check "migration : section watcher, réglages des skills gardés" \
  '{"repos":{"o/r":{"approvals":3,"test_env":"e"}},"default":{"approvals":2},"watcher":{"repos":{"o/r":{"on_pr_approved":"auto","path":"/x"},"*":{"on_pr_approved":"notify"}},"interval":9}}' \
  "$(jq -c . "$cfg")"
check "migration : copie .bak" présent "$([ -e "$cfg.bak" ] && echo présent || echo absent)"
"$bin" status >/dev/null
check "migration : une seule fois" 1 "$(jq '.watcher.repos | length == 2 | if . then 1 else 0 end' "$cfg")"

[ "$fails" = 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
