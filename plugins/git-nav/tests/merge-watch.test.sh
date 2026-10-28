#!/usr/bin/env bash
# Tests du hook merge-watch.py : bash plugins/git-nav/tests/merge-watch.test.sh
set -u
hook=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/merge-watch.py
fails=0

cwd=$(mktemp -d)   # dossier hors dépôt par défaut ; un dépôt de test pour HEAD et origin/HEAD
repo=$(mktemp -d)
trap 'rm -rf "$cwd" "$repo"' EXIT
git -C "$repo" init -q -b feat/y
git -C "$repo" update-ref refs/remotes/origin/develop "$(git -C "$repo" commit-tree -m x "$(git -C "$repo" write-tree)")"
git -C "$repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop

run() { # run <commande> → contexte ajouté par le hook (sans lancer gbr cleanup), depuis $cwd
  jq -n --arg c "$1" --arg d "$cwd" '{tool_name: "Bash", cwd: $d, tool_input: {command: $c}}' |
    MERGE_WATCH_NO_PLAN=1 python3 "$hook" | jq -r '.hookSpecificOutput.additionalContext'
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
expect cleanup 'git push origin feat/x:main' 'branche feat/x poussée sur main'
expect cleanup 'git push -u origin +refs/heads/feat/x:refs/heads/master' 'branche feat/x poussée sur master'
expect cleanup 'git push -o ci.skip origin feat/x:main' 'branche feat/x'
expect cleanup "git -C $repo push origin HEAD:develop" 'branche feat/y poussée sur develop'

expect none 'gh pr merge --auto --squash 83'
expect none 'git merge --abort'
expect none 'git merge --continue'
expect none 'git merge'
expect none 'gh pr view 83'
expect none 'git log --merges'
expect none 'echo "gh pr merge 83"'
expect none 'git commit -m "git merge feat/x"'
expect none 'echo "non fermé'
expect none 'git push'
expect none 'git push origin main'
expect none 'git push origin main:main'
expect none 'git push origin feat/x'
expect none 'git push origin feat/x:release'
expect none 'git push origin :main'
expect none 'git push --delete origin main'
expect none 'git push -n origin feat/x:main'
expect none 'git push origin abc1234:main'
expect none 'git push origin HEAD:main'
expect none "git -C $repo push origin HEAD:main"

out=$(echo '{"tool_input":{}}' | python3 "$hook")
if [ -z "$out" ]; then echo 'ok    none    (entrée sans command)'; else echo 'FAIL  none    (entrée sans command)'; fails=$((fails + 1)); fi

[ "$fails" -eq 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
