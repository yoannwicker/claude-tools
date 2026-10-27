#!/usr/bin/env bash
# Tests de gbr cleanup : bash plugins/git-nav/tests/gbr-cleanup.test.sh
# Dépôt jetable avec un origin nu ; faux gh dans le PATH (PR #7, état $STATE).
set -u
bin=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0

expect() { # expect <code> <texte attendu> <args de gbr cleanup…>
  local code=$1 text=$2 out got
  shift 2
  out=$(PATH=$tmp/fake:$bin:$PATH gbr cleanup "$@" 2>&1); got=$?
  if [ "$got" = "$code" ] && printf '%s' "$out" | grep -qF -- "$text"; then
    printf 'ok    %s\n' "$*"
  else
    printf 'FAIL  %s (code %s)\n%s\n' "$*" "$got" "$out"; fails=$((fails + 1))
  fi
}

mkdir -p "$tmp/fake"
git init -q --bare -b main "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/repo" 2>/dev/null
cd "$tmp/repo" || exit 1
git commit -q --allow-empty -m init && git push -q origin main && git remote set-head origin main

# Sans PR : feat/a mergée localement, avec worktree et sauvegarde.
printf '#!/bin/sh\n' > "$tmp/fake/gh"; chmod +x "$tmp/fake/gh"
git switch -q -c feat/a && echo a > a && git add a && git commit -qm a && git push -q -u origin feat/a 2>/dev/null
git branch backup/feat-a-1 && git switch -q main && git merge -q --no-ff -m m feat/a
git worktree add -q .claude/worktrees/feat-a feat/a 2>/dev/null
expect 0 'supprimer le worktree' --dry-run feat/a
echo x > .claude/worktrees/feat-a/x
expect 1 'gardé (dirty' --dry-run feat/a
rm .claude/worktrees/feat-a/x
(cd .claude/worktrees/feat-a && sleep 3) & sleep 0.3
expect 1 'gardé (busy' --dry-run feat/a
wait
expect 1 'branche par défaut' --dry-run main
expect 0 'supprimer origin/feat/a' --yes feat/a
[ -z "$(git branch --list feat/a backup/feat-a-1)" ] && [ ! -d .claude/worktrees/feat-a ] \
  && ! git ls-remote --exit-code origin feat/a >/dev/null \
  && echo 'ok    feat/a, sa sauvegarde, son worktree et origin/feat/a supprimés' \
  || { echo 'FAIL  feat/a pas entièrement supprimée'; fails=$((fails + 1)); }
git switch -q -c feat/b && echo b > b && git add b && git commit -qm b && git switch -q main
expect 1 "pas de PR pour feat/b et elle n'est pas contenue" --dry-run feat/b

# Avec PR : feat/s mergée en squash.
git switch -q -c feat/s && echo 1 > s && git add s && git commit -qm s1 && echo 2 >> s && git commit -qam s2
git push -q -u origin feat/s 2>/dev/null
oid=$(git rev-parse HEAD)
printf '#!/bin/sh\ncase "$*" in\n  "pr list"*) echo "7 ${STATE:-MERGED} %s" ;;\n  "pr view"*) echo feat/s ;;\nesac\n' "$oid" > "$tmp/fake/gh"
git switch -q main && git merge -q --squash feat/s >/dev/null && git commit -qm squash && git push -q
expect 0 'PR #7 mergée' --dry-run --pr 7
STATE=OPEN expect 1 'est OPEN' --dry-run feat/s
git switch -q feat/s && echo 3 >> s && git commit -qam s3
expect 1 'commits absents de la PR #7' --dry-run feat/s
git reset -q --hard HEAD~1
expect 0 'passer sur main' --dry-run
expect 0 'garder origin/feat/s' --yes --local
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] && [ -z "$(git branch --list feat/s)" ] \
  && git ls-remote --exit-code origin feat/s >/dev/null \
  && echo 'ok    --local : sur main, feat/s supprimée, origin/feat/s gardée' \
  || { echo 'FAIL  --local'; fails=$((fails + 1)); }

[ "$fails" -eq 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
