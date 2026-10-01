#!/usr/bin/env bash
# scan.sh — classe les worktrees du dépôt courant, une ligne TSV par worktree :
#   <verdict>\t<chemin>\t<branche>\t<détail>
# verdict : main | current | locked | busy | dirty | free
#   busy  = un processus de l'utilisateur a son cwd dans le worktree (session Claude, shell, IDE…)
#   dirty = modifications non commitées ou fichiers non suivis
# Seuls les « free » sont candidats à la suppression.
set -euo pipefail

current=$(git rev-parse --show-toplevel)
main=$(git worktree list --porcelain | sed -n '1s/^worktree //p')

declare -A cwd_pids=()
for d in /proc/[0-9]*; do
  [ -O "$d" ] || continue
  pid=${d#/proc/}
  [ "$pid" = "$$" ] && continue
  cwd=$(readlink "$d/cwd" 2>/dev/null) || continue
  cwd_pids[$cwd]+="$pid "
done

pids_in() {
  local wt=$1 cwd out=""
  for cwd in "${!cwd_pids[@]}"; do
    case "$cwd/" in "$wt"/*) out+=${cwd_pids[$cwd]} ;; esac
  done
  printf '%s' "$out"
}

describe_pids() {
  local pid out=""
  for pid in $1; do out+="$pid:$(cat /proc/"$pid"/comm 2>/dev/null || echo '?') "; done
  printf '%s' "${out% }"
}

unpushed() {
  local wt=$1
  if git -C "$wt" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    git -C "$wt" rev-list --count '@{u}..HEAD'
  else
    echo "sans-upstream"
  fi
}

path="" branch="" locked=""
emit() {
  [ -n "$path" ] || return 0
  local verdict detail pids
  if [ "$path" = "$main" ]; then verdict=main detail="dépôt principal"
  elif [ "$path" = "$current" ]; then verdict=current detail="worktree de cette session"
  elif [ -n "$locked" ]; then verdict=locked detail="verrouillé"
  elif [ ! -d "$path" ]; then verdict=free detail="dossier absent (prune)"
  else
    pids=$(pids_in "$path")
    if [ -n "$pids" ]; then verdict=busy detail=$(describe_pids "$pids")
    elif [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
      verdict=dirty detail="$(git -C "$path" status --porcelain | wc -l) fichier(s) modifié(s)/non suivi(s)"
    else
      verdict=free detail="commits non poussés : $(unpushed "$path")"
    fi
  fi
  printf '%s\t%s\t%s\t%s\n' "$verdict" "$path" "${branch:-détaché}" "$detail"
  path="" branch="" locked=""
}

while IFS= read -r line; do
  case "$line" in
    "worktree "*) emit; path=${line#worktree } ;;
    "branch "*) branch=${line#branch refs/heads/} ;;
    locked*) locked=1 ;;
  esac
done < <(git worktree list --porcelain)
emit
