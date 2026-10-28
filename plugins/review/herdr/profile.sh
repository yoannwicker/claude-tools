#!/usr/bin/env bash
# profile.sh install | remove | status — profil Herdr UI « custom-reviewer » : /review:pr lancé
# depuis la boîte de revue de Herdr UI (qui lit ~/.config/agent-launcher/agents/<nom>/prompt.md).
# Appelé par setup.sh (./install.sh plugin review) et par setup/20-herdr.sh.
#   install  propose le profil si Herdr UI est installé (question en terminal, refus retenu) ;
#            REVIEW_HERDR_PROFILE=1 le pose sans demander et oublie le refus
#   remove   retire le profil s'il n'a pas été modifié
#   status   signale un profil absent (non refusé) ou périmé
set -eu
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
dst=${XDG_CONFIG_HOME:-$HOME/.config}/agent-launcher/agents/custom-reviewer/prompt.md
declined=${XDG_CONFIG_HOME:-$HOME/.config}/claude-tools/herdr-review-profile-declined
pose="REVIEW_HERDR_PROFILE=1 ./install.sh plugin review"

render() { sed "s#@PLUGIN_DIR@#$dir#g" "$dir/herdr/prompt.md"; }
current() { [ -f "$dst" ] && cmp -s "$dst" <(render); }
write() { mkdir -p "$(dirname "$dst")"; render > "$dst"; echo "profil Herdr UI custom-reviewer posé (${dst/#$HOME/\~})"; }

case ${1:-} in
  install)
    command -v herdr-gpui >/dev/null 2>&1 || exit 0
    if current; then echo "profil Herdr UI custom-reviewer : à jour"; exit 0; fi
    if [ -f "$dst" ]; then   # ancienne version ou modifié : sauvegardé, jamais perdu
      bak="$dst.bak.$(date +%Y%m%d-%H%M%S)"; mv "$dst" "$bak"
      echo "profil Herdr UI custom-reviewer sauvegardé en ${bak/#$HOME/\~}"; write; exit 0
    fi
    if [ "${REVIEW_HERDR_PROFILE:-}" = 1 ]; then rm -f "$declined"; write; exit 0; fi
    if [ -f "$declined" ] || [ ! -t 0 ]; then
      echo "profil Herdr UI custom-reviewer non posé ($pose pour l'ajouter)"; exit 0
    fi
    read -r -p "Ajouter le profil Herdr UI custom-reviewer (/review:pr depuis Herdr UI) ? [O/n] " answer || answer=n
    case $answer in
      ""|[oOyY]*) write ;;
      *) mkdir -p "$(dirname "$declined")" && touch "$declined"
         echo "profil Herdr UI custom-reviewer non posé ($pose pour l'ajouter)" ;;
    esac ;;
  remove)
    [ -f "$dst" ] || exit 0
    if current; then
      rm "$dst"; rmdir "$(dirname "$dst")" 2>/dev/null || true
      echo "profil Herdr UI custom-reviewer retiré"
    else
      echo "profil Herdr UI custom-reviewer modifié, gardé (${dst/#$HOME/\~})"
    fi ;;
  status)
    command -v herdr-gpui >/dev/null 2>&1 || exit 0
    if current; then exit 0
    elif [ -f "$dst" ]; then echo "profil Herdr UI custom-reviewer périmé : ./install.sh plugin review"
    elif [ ! -f "$declined" ]; then echo "profil Herdr UI custom-reviewer absent : $pose"
    fi ;;
  *) sed -n '2,8p' "$0"; exit 2 ;;
esac
