#!/usr/bin/env bash
# install.sh — pose dans $HOME un lien par fichier de home/, puis lance setup/*.sh.
#   ./install.sh            = link + setup
#   ./install.sh link       pose/répare les liens (sauvegarde en *.bak.<date> si un fichier différent existe)
#   ./install.sh setup      exécute setup/*.sh dans l'ordre (idempotents)
#   ./install.sh status     état de chaque fichier géré ; code retour 1 si quelque chose cloche
#   ./install.sh adopt <f>… déplace un fichier de $HOME dans home/ et le remplace par un lien
#   ./install.sh capture <f>… recopie un fichier de $HOME vers home/ (repli quand un lien n'est pas possible)
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
src_root=$repo/home
dst_root=${HOME:?}

managed() { (cd "$src_root" && find . -type f | sed 's#^\./##' | LC_ALL=C sort); }

same_target() { [ -L "$1" ] && [ "$(readlink -f "$1")" = "$(readlink -f "$2")" ]; }

link_one() {
  local rel=$1 src=$src_root/$1 dst=$dst_root/$1
  mkdir -p "$(dirname "$dst")"
  if same_target "$dst" "$src"; then
    printf 'ok      %s\n' "$rel"
  elif [ -L "$dst" ]; then
    ln -sfn "$src" "$dst"
    printf 'relink  %s\n' "$rel"
  else
    if [ -e "$dst" ]; then
      if cmp -s "$dst" "$src"; then
        rm "$dst"
      else
        local bak="$dst.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$dst" "$bak"
        printf 'backup  %s -> %s\n' "$rel" "$bak"
      fi
    fi
    ln -s "$src" "$dst"
    printf 'link    %s\n' "$rel"
  fi
}

cmd_link() { while IFS= read -r rel; do link_one "$rel"; done < <(managed); }

cmd_setup() {
  local s
  for s in "$repo"/setup/*.sh; do
    printf '== %s\n' "$(basename "$s")"
    bash "$s"
  done
}

cmd_status() {
  local rel src dst rc=0
  while IFS= read -r rel; do
    src=$src_root/$rel; dst=$dst_root/$rel
    if same_target "$dst" "$src"; then
      printf 'ok      %s\n' "$rel"
    elif [ -L "$dst" ]; then
      printf 'WRONG   %s -> %s\n' "$rel" "$(readlink "$dst")"; rc=1
    elif [ -e "$dst" ]; then
      if cmp -s "$dst" "$src"; then
        printf 'copy    %s (fichier normal, identique)\n' "$rel"
      else
        printf 'DIFF    %s (fichier normal différent : diff, puis adopt ou capture)\n' "$rel"; rc=1
      fi
    else
      printf 'MISSING %s\n' "$rel"; rc=1
    fi
  done < <(managed)
  return $rc
}

to_rel() {
  local abs
  abs=$(realpath -s -- "$1")
  case "$abs" in
    "$dst_root"/*) printf '%s\n' "${abs#"$dst_root"/}" ;;
    *) printf 'hors de $HOME : %s\n' "$1" >&2; return 1 ;;
  esac
}

cmd_adopt() {
  local path rel abs
  for path in "$@"; do
    rel=$(to_rel "$path"); abs=$dst_root/$rel
    if [ -L "$abs" ]; then printf 'déjà un lien : %s\n' "$rel"; continue; fi
    [ -f "$abs" ] || { printf 'pas un fichier : %s\n' "$path" >&2; return 1; }
    mkdir -p "$src_root/$(dirname "$rel")"
    mv "$abs" "$src_root/$rel"
    ln -s "$src_root/$rel" "$abs"
    printf 'adopt   %s\n' "$rel"
  done
}

cmd_capture() {
  local path rel abs
  for path in "$@"; do
    rel=$(to_rel "$path"); abs=$dst_root/$rel
    [ -f "$abs" ] && [ ! -L "$abs" ] || { printf 'pas un fichier normal : %s\n' "$path" >&2; return 1; }
    mkdir -p "$src_root/$(dirname "$rel")"
    cp -p "$abs" "$src_root/$rel"
    printf 'capture %s\n' "$rel"
  done
}

case "${1:-all}" in
  all)     cmd_link; cmd_setup ;;
  link)    cmd_link ;;
  setup)   cmd_setup ;;
  status)  cmd_status ;;
  adopt)   shift; [ $# -gt 0 ] || { sed -n '2,8p' "$0"; exit 2; }; cmd_adopt "$@" ;;
  capture) shift; [ $# -gt 0 ] || { sed -n '2,8p' "$0"; exit 2; }; cmd_capture "$@" ;;
  *)       sed -n '2,8p' "$0"; exit 2 ;;
esac
