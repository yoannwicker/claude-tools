#!/usr/bin/env bash
# Tests de gh-watch : bash plugins/gh-watch/tests/gh-watch.test.sh
# Faux watchers déclarés dans un watchers.d temporaire, faux systemctl. Rien n'est lancé.
set -u
bin=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/gh-watch
fails=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GH_WATCH_DIR=$tmp/watchers.d GH_WATCH_CONFIG=$tmp/gh-watch.json GH_WATCH_STATE=$tmp/gh-watch-state.json PATH=$tmp/fakebin:$PATH
mkdir -p "$GH_WATCH_DIR" "$tmp/fakebin"
unset HERDR_PANE_ID  # jamais le vrai herdr de la session qui lance les tests

check() { # check <libellé> <attendu> <obtenu>
  if [ "$2" = "$3" ]; then printf 'ok    %s\n' "$1"
  else printf 'FAIL  %s (attendu : %s, obtenu : %s)\n' "$1" "$2" "$3"; fails=$((fails + 1)); fi
}

# fake-watch <nom> <état du timer> : répond à status --json et poll --dry-run
fake() {
  cat > "$tmp/$1" <<EOF
#!/usr/bin/env bash
case "\$1 \${2:-}" in
  "status --json") cat <<'J'
{"name": "$1", "timer": "$1.timer", "state": "$2", "interval": 5,
 "last": "2026-11-05T07:00:00Z", "next": "2026-11-05T07:05:00Z", "kinds": ["approved"],
 "default": {"approved": "off"},
 "skill": {"approved": "git-tidy:ready"}, "board": {"approved": "approved"},
 "suggest": {"behind": "git-tidy:pr-sync"},
 "repos": [{"repo": "o/r", "approved": "auto", "approvals": 2, "path": "/x"}],
 "sessions": [{"key": "o/r#3:approved", "mode": "background", "status": "ready",
               "resume": "$1 resume o/r#3 approved", "launched": "2026-11-05T06:00:00Z"}],
 "history": [
   {"when": "2020-01-01T00:00:00Z", "key": "o/r#1:approved", "kind": "approved", "repo": "o/r", "n": 1,
    "action": "notifié", "detail": "vieux"},
   {"when": "$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ)", "key": "o/r#3:approved", "kind": "approved",
    "repo": "o/r", "n": 3, "action": "lancé", "detail": "analyse lancée en fond ($1)"}]}
J
  ;;
  "poll --dry-run") echo "o/r#4 (approved, auto) : lancerait" ;;
  launch\ *) echo "$1 \$*" >> "$tmp/calls.log"; echo "\$2:\$3 : lancé ($1)" ;;
  skip\ *) echo "$1 \$*" >> "$tmp/calls.log"; echo "écarté" ;;
  *) exit 2 ;;
esac
EOF
  chmod +x "$tmp/$1"
  ln -sfn "$tmp/$1" "$GH_WATCH_DIR/$1"
}

check "aucun watcher déclaré" "aucun watcher déclaré ($GH_WATCH_DIR)" "$("$bin" status)"

fake a-watch active
fake b-watch inactive
ln -sfn "$tmp/absent" "$GH_WATCH_DIR/c-watch"

check "list : déclarés, lien mort signalé" "a-watch|b-watch|c-watch (lien mort)" \
  "$("$bin" list | awk '{print $1 ($2 == "(lien" ? " (lien mort)" : "")}' | paste -sd'|')"
out=$("$bin" status)
check "status : un bloc par watcher" 3 "$(grep -c '^== ' <<<"$out")"
check "timer arrêté avec un dépôt en auto → signalé" 1 "$(grep -c 'b-watch.timer : inactive.*⚠ arrêté' <<<"$out")"
check "session prête → commande resume" 2 "$(grep -c 'resume o/r#3 approved' <<<"$out")"
check "lien mort → erreur, les autres affichés" 1 "$(grep -A1 '^== c-watch' <<<"$out" | grep -c 'erreur : script introuvable')"
check "--json" "a-watch active 2" \
  "$("$bin" status --json | jq -r '.[0] | "\(.name) \(.state) \(.repos[0].approvals)"')"
check "session : heure de lancement" 2 "$(grep -c 'ready, lancée 05/11' <<<"$out")"
check "status : derniers déclenchements" 2 "$(grep -c 'o/r#3 (approved)  lancé — analyse lancée en fond' <<<"$out")"
check "history : tous, du plus récent au plus ancien" "lancé lancé notifié notifié" \
  "$("$bin" history --json | jq -r '[.[].action] | join(" ")')"
check "history --since 1h : les récents seulement" "a-watch b-watch" \
  "$("$bin" history --since 1h --json | jq -r '[.[].watcher] | sort | join(" ")')"
check "--since invalide → erreur" 2 "$("$bin" history --since demain >/dev/null 2>&1; echo $?)"
check "--dry-run : ce qu'un passage ferait" 2 "$("$bin" status --dry-run | grep -c 'passage : o/r#4 (approved, auto) : lancerait')"

# --- board : faux gh (recherche, détail des PR, comparaison avec la base) ---
cat > "$tmp/fakebin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "api graphql --input -")
    q=$(cat)
    case "$q" in
      *'search('*) echo "$q" >> "${GH_FAKE_LOG:-/dev/null}"
        extra=; [ -n "${GH_FAKE_EXTRA:-}" ] && extra=', {"id": "C", "repository": {"nameWithOwner": "o/r"}}'
        echo '{"data": {"mine": {"nodes": [{"id": "A", "repository": {"nameWithOwner": "o/r"}}'"$extra"']},
          "requested": {"nodes": [{"id": "B", "repository": {"nameWithOwner": "o/r"}}]},
          "reviewed": {"nodes": []}, "mentioned": {"nodes": []}, "viewer": {"login": "moi"}}}' ;;
      *'nodes(ids'*) if [ -n "${GH_FAKE_EXTRA:-}" ]; then cat "$(dirname "$0")/../nodes-extra.json"
                     else cat "$(dirname "$0")/../nodes.json"; fi ;;
    esac ;;
  api\ repos/o/r/compare/*) echo 3 ;;
  "repo view --json nameWithOwner --jq .nameWithOwner") [ -z "${GH_FAKE_NOREPO:-}" ] && echo O/R || exit 1 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/fakebin/gh"
cat > "$tmp/nodes.json" <<'EOF'
{"data": {"nodes": [
 {"id": "A", "number": 7, "title": "Ma PR", "url": "u7", "isDraft": false, "createdAt": "2026-11-02T08:00:00Z",
  "headRefOid": "abc", "baseRefName": "main", "author": {"login": "moi"}, "repository": {"nameWithOwner": "o/r"},
  "mergeable": "MERGEABLE", "mergeStateStatus": "CLEAN", "reviewRequests": {"nodes": []}, "timelineItems": {"nodes": []},
  "latestOpinionatedReviews": {"nodes": [
    {"author": {"__typename": "User", "login": "bob"}, "state": "APPROVED", "submittedAt": "2026-11-04T10:00:00Z"},
    {"author": {"__typename": "User", "login": "carol"}, "state": "APPROVED", "submittedAt": "2026-11-04T11:00:00Z"}]},
  "reviews": {"nodes": []}, "reviewThreads": {"nodes": []}, "commits": {"nodes": []}},
 {"id": "B", "number": 9, "title": "Sa PR", "url": "u9", "isDraft": false, "createdAt": "2026-11-02T08:00:00Z",
  "headRefOid": "def", "baseRefName": "main", "author": {"login": "alice"}, "repository": {"nameWithOwner": "o/r"},
  "mergeable": "MERGEABLE", "mergeStateStatus": "CLEAN",
  "reviewRequests": {"nodes": [{"requestedReviewer": {"__typename": "User", "login": "moi"}}]},
  "timelineItems": {"nodes": [{"__typename": "ReviewRequestedEvent", "createdAt": "2026-11-03T08:00:00Z",
    "actor": {"login": "alice"}, "requestedReviewer": {"__typename": "User", "login": "moi"}}]},
  "latestOpinionatedReviews": {"nodes": []}, "reviews": {"nodes": []}, "reviewThreads": {"nodes": []},
  "commits": {"nodes": []}}]}}
EOF
export GH_FAKE_LOG=$tmp/gh.log
out=$(COLUMNS=100 "$bin" board)
check "board : dépôt courant, à toi" "o/r — 2 à toi| À toi" "$(head -2 <<<"$out" | paste -sd'|')"
check "board : approuvée → skill du watcher qui la prend en charge" 1 \
  "$(grep -cE '^  #7  ✓✓ approuvée 2/2, en retard  [0-9]+ (min|h|j)( ⚠)? +/git-tidy:ready  Ma PR$' <<<"$out")"
check "board : relecture demandée, aucun watcher pour elle → pas d'action" 1 \
  "$(grep -cE '^  #9  à relire +[0-9]+ (h|j) ⚠ +Sa PR$' <<<"$out")"
out=$("$bin" board --all)
check "board --all : le dépôt puis ce qui est à moi, sans titres de groupe" "o/r 2 0" \
  "$(head -1 <<<"$out") $(grep -c '^  #' <<<"$out") $(grep -c '^ [^ ]' <<<"$out")"
check "board hors d'un clone → tous les dépôts" "(hors d'un clone GitHub : tous les dépôts)" \
  "$(GH_FAKE_NOREPO=1 "$bin" board | head -1)"
check "board : un dépôt et --all → erreur" 1 "$("$bin" board o/r --all >/dev/null 2>&1; echo $?)"
check "board --json" "approved a-watch approved behind|to_review -" \
  "$("$bin" board --all --json | jq -r '.prs[] | [.state, (.action.watcher // "-"), (.action.kind // empty), (.alerts | join(","))] | map(select(. != "")) | join(" ")' | paste -sd'|')"
: > "$GH_FAKE_LOG"
"$bin" board >/dev/null
check "board : recherches restreintes au dépôt courant" 4 "$(grep -o 'repo:o/r' "$GH_FAKE_LOG" | wc -l)"
check "board : dépôt invalide → erreur" 1 "$("$bin" board pas-un-depot >/dev/null 2>&1; echo $?)"
check "set others open" "o/r : others = open" "$("$bin" set others o/r open)"
: > "$GH_FAKE_LOG"
"$bin" board --all >/dev/null
check "others = open → recherche des PR ouvertes des autres" 1 "$(grep -c 'repo:o/r -author:@me draft:false' "$GH_FAKE_LOG")"
check "set others default" "o/r : others = requested" "$("$bin" set others o/r default)"
check "set stale_days" "stale_days = 50 jour(s) ouvré(s)" "$("$bin" set stale_days 50)"
check "stale_days 50 → plus de ⚠" 0 "$("$bin" board --all | grep -c '⚠')"
check "set stale_days invalide → erreur" 1 "$("$bin" set stale_days zéro >/dev/null 2>&1; echo $?)"

check "board --auto : seulement les états suivis par un watcher" "#7" "$("$bin" board --auto | awk '{print $1}' | paste -sd'|')"
check "board --missed : approuvée jamais vue → commande de lancement" 1 \
  "$("$bin" board --missed | grep -c 'auto  manquée : pas vue  gh-watch launch o/r#7')"
check "board --missed --json : suivi" "a-watch approved auto true" \
  "$("$bin" board --missed --json | jq -r '.prs[0].watch | "\(.watcher) \(.kind) \(.mode) \(.missed)"')"
check "board --auto et --missed ensemble → erreur" 2 "$("$bin" board --auto --missed >/dev/null 2>&1; echo $?)"
# --- launch, skip, unskip ---
: > "$tmp/calls.log"
check "launch : par le watcher qui gère l'état, événement retenu" "o/r#7:approved : lancé (a-watch)|a-watch launch o/r#7 approved --at 2026-11-04T11:00:00Z" \
  "$({ "$bin" launch o/r#7; cat "$tmp/calls.log"; } | paste -sd'|')"
check "launch : n seul → dépôt courant ; ligne sans action → refus" "1 1" \
  "$("$bin" launch 9 >/dev/null; echo $?) $("$bin" launch 9 | grep -c "pas d'action à lancer")"
check "launch : PR absente du tableau → erreur" 1 "$("$bin" launch o/r#42 >/dev/null 2>&1; echo $?)"
: > "$tmp/calls.log"
"$bin" board --missed --launch >/dev/null
check "board --missed --launch : lance les manquées" "a-watch launch o/r#7 approved --at 2026-11-04T11:00:00Z" "$(cat "$tmp/calls.log")"
check "board --launch sans --missed → erreur" 1 "$("$bin" board --launch >/dev/null 2>&1; echo $?)"
: > "$tmp/calls.log"
check "skip : jusqu'au prochain événement" "o/r#7 (✓✓ approuvée 2/2) : écartée jusqu'au prochain événement" "$("$bin" skip o/r#7)"
check "skip : relayé au watcher" "a-watch skip o/r#7 approved --at 2026-11-04T11:00:00Z" "$(cat "$tmp/calls.log")"
out=$("$bin" board --missed)
check "écartée : masquée, comptée" "aucune action manquée sur o/r|(1 écartée(s) : --skipped pour les voir, gh-watch unskip <repo#n>)" \
  "$(paste -sd'|' <<<"$out")"
check "--skipped : montrée" 1 "$("$bin" board --skipped | grep -c '#7  écartée : ✓✓ approuvée 2/2')"
check "unskip" "o/r#7 : réintégrée (pour la lancer : gh-watch launch o/r#7)" "$("$bin" unskip o/r#7)"
check "unskip d'une ligne non écartée → erreur" 1 "$("$bin" unskip o/r#7 >/dev/null 2>&1; echo $?)"
check "skip --until-closed" "o/r#9 (à relire) : écartée jusqu'à la fermeture de la PR" "$("$bin" skip 9 --until-closed)"
check "écartée jusqu'à la fermeture : masquée" 0 "$("$bin" board | grep -c '#9')"
jq '.skipped["o/r#99"] = {"state": "to_review", "event": "x", "until_closed": true}' "$GH_WATCH_STATE" > "$tmp/s" && mv "$tmp/s" "$GH_WATCH_STATE"
"$bin" board >/dev/null
check "écart d'une PR fermée oublié, les autres gardés" "o/r#9" "$(jq -r '.skipped | keys | join(" ")' "$GH_WATCH_STATE")"
"$bin" unskip 9 >/dev/null

# --- toute action proposée se lance ; en fond au choix ; -i ---
jq '.data.nodes += [.data.nodes[0] | .id = "C" | .number = 8 | .title = "En retard" | .latestOpinionatedReviews.nodes = []]' \
  "$tmp/nodes.json" > "$tmp/nodes-extra.json"
check "à faire relire et en retard → /git-tidy:pr-sync proposé, pas lançable" "1|o/r#8 (à faire relire) : pas d'action à lancer (/git-tidy:pr-sync 8)" \
  "$(GH_FAKE_EXTRA=1 "$bin" launch o/r#8 >/dev/null; echo $?)|$(GH_FAKE_EXTRA=1 "$bin" launch o/r#8)"
check "launch d'une ligne sans action → refus" "1|o/r#9 (à relire) : pas d'action à lancer" \
  "$("$bin" launch 9 >/dev/null; echo $?)|$("$bin" launch 9)"
: > "$tmp/calls.log"
"$bin" board --missed --launch --background >/dev/null
check "board --missed --launch --background" "a-watch launch o/r#7 approved --at 2026-11-04T11:00:00Z --background" "$(cat "$tmp/calls.log")"
check "--background sans --launch → erreur" 1 "$("$bin" board --background >/dev/null 2>&1; echo $?)"
check "board -i hors terminal, sans herdr → erreur" "gh-watch: board -i : il faut un terminal (ou herdr)" "$("$bin" board -i 2>&1 </dev/null)"
cat > "$tmp/fakebin/herdr" <<EOF
#!/usr/bin/env bash
echo "herdr \$*" >> "$tmp/herdr.log"
case "\$1 \$2" in
  "status server") echo "status: running" ;;
  "pane split") echo '{"result": {"pane": {"pane_id": "w1:p2"}}}' ;;
esac
EOF
chmod +x "$tmp/fakebin/herdr"
out=$(HERDR_PANE_ID=w1:p1 "$bin" board o/r --missed -i 2>&1 </dev/null)
check "board -i hors terminal, dans herdr → pane ouvert sous la session" \
  "liste ouverte dans un pane herdr sous la session (w1:p2) : q pour la fermer" "$out"
check "… qui relance la liste avec les mêmes options" 1 \
  "$(grep -c "^herdr pane run w1:p2 exec sh -c '$bin board o/r --missed -i ||" "$tmp/herdr.log")"
rm "$tmp/fakebin/herdr"
check "board -i --json → erreur" 1 "$("$bin" board -i --json >/dev/null 2>&1; echo $?)"

check "set board o off → dépôts écartés" "aucune PR ouverte qui te concerne (dépôts filtrés : gh-watch set board)" \
  "$("$bin" set board o off >/dev/null; "$bin" board --all)"
check "board <dépôt> : jamais filtré" 1 "$("$bin" board o/r | grep -c '^o/r')"
check "un autre propriétaire activé → seulement lui" "aucune PR" \
  "$("$bin" set board o default >/dev/null; "$bin" set board autre on >/dev/null; "$bin" board --all | cut -d' ' -f1,2)"
check "dépôt activé : l'emporte sur son propriétaire" "o/r" \
  "$("$bin" set board o off >/dev/null; "$bin" set board o/r on >/dev/null; "$bin" board --all | head -1)"
check "set board sans argument : réglages" "board --all : seulement les propriétaires et dépôts activés|  autre  on|  o  off|  o/r  on" \
  "$("$bin" set board | paste -sd'|')"
check "set board : valeur invalide → erreur" 1 "$("$bin" set board o peut-être >/dev/null 2>&1; echo $?)"

# --- rattrapage quotidien (board_auto) ---
check "status : rattrapage off par défaut" "rattrapage quotidien : off (gh-watch set board_auto on)" \
  "$("$bin" status | tail -1)"
check "set board_auto on" "board_auto = on" "$("$bin" set board_auto on | cut -d' ' -f1-3)"
check "set board_auto : valeur invalide → erreur" 1 "$("$bin" set board_auto oui >/dev/null 2>&1; echo $?)"
check "catchup : jamais lancé" "rattrapage quotidien : on ; dernier : jamais lancé" "$("$bin" catchup)"
# Dernier rattrapage (écrit par watchlib) : #7 toujours manquée, #3 lancée depuis (historique
# de a-watch), #9 écartée depuis, #5 trop récente (moins d'un jour ouvré)
row() { echo "{\"repo\": \"o/r\", \"n\": $1, \"title\": \"PR $1\", \"state\": \"approved\", \"short\": \"approuvée 2/2\",
  \"event_at\": \"$2\", \"watcher\": \"a-watch\", \"kind\": \"approved\"}"; }
jq '.skipped["o/r#9"] = {"state": "approved", "event": "x", "until_closed": true}' "$GH_WATCH_STATE" > "$tmp/s" && mv "$tmp/s" "$GH_WATCH_STATE"
cat > "$(dirname "$GH_WATCH_STATE")/catchup.json" <<EOF
{"day": "$(date +%F)", "started": "2026-11-05T07:00:00Z", "finished": "2026-11-05T07:00:30Z", "by": "a-watch",
 "count": 4, "error": null, "rows": [$(row 7 2026-11-04T11:00:00Z), $(row 3 2026-11-04T11:00:00Z),
 $(row 9 2026-11-04T11:00:00Z), $(row 5 "$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ)")]}
EOF
check "catchup --json : manquées depuis plus d'un jour ouvré, encore manquées" "on 4 7:gh-watch launch o/r#7" \
  "$("$bin" catchup --json | jq -r '"\(.board_auto) \(.last.count) \([.waiting[] | "\(.n):\(.command)"] | join(","))"')"
out=$("$bin" status)
check "status : dernier rattrapage" 1 "$(grep -c '^rattrapage quotidien : on ; dernier : 05/11 .* (a-watch) — 4 manquée(s)$' <<<"$out")"
check "status : manquée en attente, avec sa commande" 1 \
  "$(grep -cE '^    o/r#7  approuvée 2/2  approved  [0-9]+ j ouvrés  gh-watch launch o/r#7$' <<<"$out")"
"$bin" set board_auto off >/dev/null
check "set board_auto off → retiré de la config" null "$(jq -r '.board_auto // "null"' "$GH_WATCH_CONFIG")"

[ "$fails" = 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
