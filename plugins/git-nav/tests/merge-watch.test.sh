#!/usr/bin/env bash
# Tests du hook merge-watch.py : bash plugins/git-nav/tests/merge-watch.test.sh
set -u
hook=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/merge-watch.py
fails=0

run() { # run <commande> → sortie du hook (sans lancer gbr cleanup)
  jq -n --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}' | MERGE_WATCH_NO_PLAN=1 python3 "$hook"
}

expect() { # expect cleanup|none <commande> [texte attendu dans le contexte]
  local out got
  out=$(run "$2")
  if printf '%s' "$out" | grep -q 'git-nav:branch-cleanup'; then got=cleanup; else got=none; fi
  if [ "$got" = "$1" ] && { [ -z "${3:-}" ] || printf '%s' "$out" | grep -qF -- "$3"; }; then
    printf 'ok    %-7s %s\n' "$1" "$2"
  else
    printf 'FAIL  %-7s %s (obtenu : %s %s)\n' "$1" "$2" "$got" "$out"; fails=$((fails + 1))
  fi
}

expect cleanup 'gh pr merge' 'PR de la branche courante'
expect cleanup 'gh pr merge 83 --squash' 'PR 83'
expect cleanup 'gh pr merge --rebase --delete-branch 12' 'PR 12'
expect cleanup 'git merge feat/x' 'branche feat/x'
expect cleanup 'git merge --no-ff feat/x' 'branche feat/x'
expect cleanup 'git merge -m "Merge x" -s ort feat/x' 'branche feat/x)'
expect cleanup 'git -C ../repo merge feat/x' 'branche feat/x'
expect cleanup 'git switch main && git merge feat/x && git push' 'branche feat/x'
expect cleanup 'GH_REPO=a/b gh pr merge 5' 'PR 5'

expect none 'gh pr merge --auto --squash 83'
expect none 'git merge --abort'
expect none 'git merge --continue'
expect none 'git merge'
expect none 'gh pr view 83'
expect none 'git log --merges'
expect none 'echo "gh pr merge 83"'
expect none 'git commit -m "git merge feat/x"'
expect none 'echo "non fermé'

out=$(echo '{"tool_input":{}}' | python3 "$hook")
if [ -z "$out" ]; then echo 'ok    none    (entrée sans command)'; else echo 'FAIL  none    (entrée sans command)'; fails=$((fails + 1)); fi

[ "$fails" -eq 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
