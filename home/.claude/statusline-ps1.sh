#!/usr/bin/env bash
# Status line converted from the ~/.bashrc PS1:
#   \u@\h (green bold) : \w (blue bold), trailing \$ removed
input=$(cat)
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$dir" ] && dir=$(pwd)
case "$dir" in
  "$HOME"*) dir="~${dir#"$HOME"}" ;;
esac
printf '\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m' "$(whoami)" "$(hostname -s)" "$dir"
