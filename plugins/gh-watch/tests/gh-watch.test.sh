#!/usr/bin/env bash
# Tests de gh-watch : bash plugins/gh-watch/tests/gh-watch.test.sh
# Faux watchers déclarés dans un watchers.d temporaire, faux systemctl. Rien n'est lancé.
set -u
bin=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/gh-watch
fails=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GH_WATCH_DIR=$tmp/watchers.d PATH=$tmp/fakebin:$PATH
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

[ "$fails" = 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
