#!/usr/bin/env bash
# Tests de review-post : bash plugins/review/tests/review-post.test.sh
set -u
bin=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/review-post
fails=0

# Faux gh dans le PATH : réponses fixes, et trace des écritures dans $tmp/calls.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/gh" <<'EOF'
#!/usr/bin/env bash
shift  # api
case "$*" in
  *"-X DELETE"*|*"-X POST"*) echo "$*" >> "$FAKE/calls"; cat >/dev/null
                             echo '{"html_url": "https://github.com/o/r/pull/7#pullrequestreview-1"}' ;;
  user) echo '{"login": "moi"}' ;;
  "repos/{owner}/{repo}/pulls/7") echo '{"state": "open", "head": {"sha": "abc"}}' ;;
  "repos/{owner}/{repo}/pulls/7/files"*)
    jq -n '[{filename: "a.py", patch: "@@ -1,3 +1,4 @@\n ctx\n-old\n+new1\n+new2\n ctx2\n\\ No newline at end of file"},
            {filename: "b.py", patch: "@@ -10,2 +20,2 @@\n x\n+y"},
            {filename: "bin.png"}]' ;;
  "repos/{owner}/{repo}/pulls/7/reviews"*) cat "$FAKE/reviews" ;;
  *) echo "faux gh : appel inattendu $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$tmp/gh"
export FAKE=$tmp PATH=$tmp:$PATH

check() { # check <libellé> <attendu> <obtenu>
  if [ "$2" = "$3" ]; then printf 'ok    %s\n' "$1"
  else printf 'FAIL  %s (attendu : %s, obtenu : %s)\n' "$1" "$2" "$3"; fails=$((fails + 1)); fi
}

cat > "$tmp/review.json" <<'EOF'
{"body": "Revue", "comments": [
  {"path": "a.py", "line": 1, "body": "contexte"},
  {"path": "a.py", "line": 2, "body": "ajout"},
  {"path": "a.py", "line": 3, "body": "ajout 2"},
  {"path": "a.py", "line": 4, "body": "contexte fin"},
  {"path": "a.py", "line": 5, "body": "après le hunk"},
  {"path": "b.py", "line": 21, "body": "ajout b"},
  {"path": "b.py", "line": 10, "body": "ancien numéro"},
  {"path": "c.py", "line": 1, "body": "fichier hors PR"},
  {"path": "bin.png", "line": 1, "body": "binaire"}]}
EOF

echo '[]' > "$tmp/reviews"
out=$("$bin" 7 "$tmp/review.json" --dry-run)
check "lignes commentables" "a.py:1 a.py:2 a.py:3 a.py:4 b.py:21" \
  "$(jq -r '[.review.comments[] | "\(.path):\(.line)"] | join(" ")' <<<"$out")"
check "hors diff → corps" 4 "$(jq -r .moved_to_body <<<"$out")"
check "corps" 'Revue|- `a.py:5` — après le hunk' \
  "$(jq -r '.review.body | split("\n") | .[0] + "|" + .[2]' <<<"$out")"
check "event COMMENT, commit de tête" "COMMENT abc" "$(jq -r '"\(.review.event) \(.review.commit_id)"' <<<"$out")"

echo '[{"id": 9, "state": "PENDING", "user": {"login": "moi"}, "html_url": "u"},
       {"id": 8, "state": "PENDING", "user": {"login": "autre"}, "html_url": "v"}]' > "$tmp/reviews"
"$bin" 7 "$tmp/review.json" --dry-run >/dev/null 2>&1
check "pending à soi → refus" 3 $?
check "--replace-pending : seulement la sienne" 9 \
  "$("$bin" 7 "$tmp/review.json" --dry-run --replace-pending | jq -r '.delete_pending | join(",")')"

: > "$tmp/calls"
url=$("$bin" 7 "$tmp/review.json" --replace-pending 2>/dev/null)
check "publication : URL" "https://github.com/o/r/pull/7#pullrequestreview-1" "$url"
check "publication : DELETE puis POST" "DELETE POST" \
  "$(sed -E 's/.*-X (DELETE|POST).*/\1/' "$tmp/calls" | paste -sd' ')"

echo '{"body": "", "comments": []}' > "$tmp/empty.json"
"$bin" 7 "$tmp/empty.json" --dry-run >/dev/null 2>&1
check "rien à publier → erreur" 1 $?

[ "$fails" -eq 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
