#!/usr/bin/env bash
# Tests de gh-watch : bash plugins/gh-watch/tests/gh-watch.test.sh
# Faux watchers déclarés dans un watchers.d temporaire, faux systemctl. Rien n'est lancé.
set -u
bin=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/gh-watch
fails=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GH_WATCH_DIR=$tmp/watchers.d GH_WATCH_CONFIG=$tmp/gh-watch.json PATH=$tmp/fakebin:$PATH
mkdir -p "$GH_WATCH_DIR" "$tmp/fakebin"

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
 "skill": {"approved": "git-tidy:ready"}, "board": {"approved": "approved"}, "suggest": {"behind": "git-tidy:pr-sync"},
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
        echo '{"data": {"mine": {"nodes": [{"id": "A", "repository": {"nameWithOwner": "o/r"}}]},
          "requested": {"nodes": [{"id": "B", "repository": {"nameWithOwner": "o/r"}}]},
          "reviewed": {"nodes": []}, "mentioned": {"nodes": []}, "viewer": {"login": "moi"}}}' ;;
      *'nodes(ids'*) cat "$(dirname "$0")/../nodes.json" ;;
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
  "$(grep -cE '^  #7  approuvée 2/2, en retard  [0-9]+ (min|h|j) +/git-tidy:ready  Ma PR$' <<<"$out")"
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
  "$("$bin" board --missed | grep -c 'auto  manquée : pas vue  a-watch launch o/r#7 approved')"
check "board --missed --json : suivi" "a-watch approved auto true" \
  "$("$bin" board --missed --json | jq -r '.prs[0].watch | "\(.watcher) \(.kind) \(.mode) \(.missed)"')"
check "board --auto et --missed ensemble → erreur" 2 "$("$bin" board --auto --missed >/dev/null 2>&1; echo $?)"
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

[ "$fails" = 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
