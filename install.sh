#!/usr/bin/env bash
# install.sh — pose dans $HOME un lien par fichier de home/, installe les plugins, lance setup/*.sh.
#   ./install.sh            = link + plugin --all + setup
#   ./install.sh link       pose/répare les liens (sauvegarde en *.bak.<date> si un fichier différent existe)
#   ./install.sh setup      exécute setup/*.sh dans l'ordre (idempotents)
#   ./install.sh plugin <p>… installe ou met à jour ces plugins, avec ce qu'ils posent hors d'eux (setup.sh)
#   ./install.sh plugin --all | --remove <p>… | --remove --all ; sans argument : état des plugins
#   ./install.sh status     état des liens et des plugins ; code retour 1 si quelque chose cloche
#   ./install.sh adopt <f>… déplace un fichier de $HOME dans home/ et le remplace par un lien
#   ./install.sh capture <f>… recopie un fichier de $HOME vers home/ (repli quand un lien n'est pas possible)
# Plugins : ceux de .claude-plugin/marketplace.json (marketplace locale « claude-tools »). Leurs
# dépendances hors du plugin sont déclarées dans plugins/<p>/setup.sh, sourcé ici : links=( "<chemin
# dans le plugin> <destination>" … ) et, facultatifs, on_install, on_remove, on_status. Les
# plugins dont il dépend (`dependencies` de son plugin.json) sont installés avant lui.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
src_root=$repo/home
dst_root=${HOME:?}
plugins_root=$repo/plugins
marketplace=claude-tools
settings=$dst_root/.claude/settings.json

usage() { sed -n '2,10p' "$0"; }

managed() { (cd "$src_root" && find . -type f | sed 's#^\./##' | LC_ALL=C sort); }

same_target() { [ -L "$1" ] && [ "$(readlink -f "$1")" = "$(readlink -f "$2")" ]; }

# link_one <source> <destination> <libellé> : lien posé ou réparé ; un fichier ordinaire différent
# est sauvegardé en *.bak.<date>, jamais perdu.
link_one() {
  local src=$1 dst=$2 label=$3
  mkdir -p "$(dirname "$dst")"
  if same_target "$dst" "$src"; then
    printf 'ok      %s\n' "$label"
  elif [ -L "$dst" ]; then
    ln -sfn "$src" "$dst"
    printf 'relink  %s\n' "$label"
  else
    if [ -e "$dst" ]; then
      if cmp -s "$dst" "$src"; then
        rm "$dst"
      else
        local bak="$dst.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$dst" "$bak"
        printf 'backup  %s -> %s\n' "$label" "$bak"
      fi
    fi
    ln -s "$src" "$dst"
    printf 'link    %s\n' "$label"
  fi
}

# Liens morts vers le dépôt : restes d'anciennes installations (fichier déplacé de home/ vers un
# plugin, retiré du dépôt). Seuls ces liens sont visés : ni fichier ordinaire, ni lien vers ailleurs.
orphans() {
  local l
  {
    [ -d "$dst_root/.claude" ] && find "$dst_root/.claude" -maxdepth 3 \
      \( -path "$dst_root/.claude/projects" -o -path "$dst_root/.claude/plugins" \) -prune -o -xtype l -print
    [ -d "$dst_root/.claude-profiles" ] && find "$dst_root/.claude-profiles" -mindepth 2 -maxdepth 2 -xtype l
    for l in "$dst_root/.config/shell" "$dst_root/.local/bin"; do
      [ -d "$l" ] && find "$l" -maxdepth 1 -xtype l
    done
  } | while IFS= read -r l; do
    case "$(readlink "$l")" in "$repo"/*) printf '%s\n' "$l" ;; esac
  done
}

# Retire les orphelins, et le dossier de ~/.claude qui les contenait s'il en reste vide
# (~/.claude/rules, ~/.claude/skills/<skill>).
sweep_orphans() {
  local l d t
  while IFS= read -r l; do
    t=$(readlink "$l"); rm "$l"
    printf 'orphan  %s -> %s (lien mort vers le dépôt, retiré)\n' "${l#"$dst_root"/}" "${t#"$repo"/}"
    d=$(dirname "$l")
    case "$d" in "$dst_root"/.claude/*) rmdir "$d" 2>/dev/null || true ;; esac
  done < <(orphans)
}

cmd_link() {
  local rel
  while IFS= read -r rel; do link_one "$src_root/$rel" "$dst_root/$rel" "$rel"; done < <(managed)
  sweep_orphans
}

cmd_setup() {
  local s
  for s in "$repo"/setup/*.sh; do
    printf '== %s\n' "$(basename "$s")"
    bash "$s"
  done
}

## Plugins

plugin_names() { jq -r '.plugins[].name' "$repo/.claude-plugin/marketplace.json"; }

# Dépendances d'un plugin (`dependencies` de son plugin.json, plugins de ce dépôt).
plugin_deps() {
  local f=$plugins_root/$1/.claude-plugin/plugin.json
  [ -f "$f" ] || return 0
  jq -r '.dependencies // [] | .[] | if type == "string" then . else .name end | sub("@.*"; "")' "$f"
}

# with_deps <p>… : les plugins demandés précédés de leurs dépendances (récursif, sans doublon).
with_deps() {
  local -A seen=()
  local -a out=()
  visit() {
    local q d
    q=$1
    [ -n "${seen[$q]:-}" ] && return
    seen[$q]=1
    for d in $(plugin_deps "$q"); do visit "$d"; done
    out+=("$q")
  }
  local p
  for p in "$@"; do visit "$p"; done
  printf '%s\n' "${out[@]}"
}

# Liens déclarés par plugins/<p>/setup.sh, « <source absolue>\t<destination absolue> » par ligne.
plugin_links() {
  local p=$1 f=$plugins_root/$1/setup.sh
  [ -f "$f" ] || return 0
  (
    links=()
    # shellcheck source=/dev/null
    . "$f"
    for l in "${links[@]}"; do
      set -- $l
      printf '%s\t%s\n' "$plugins_root/$p/$1" "${2/#\~/$dst_root}"
    done
  )
}

# plugin_hook <p> <on_install|on_remove|on_status> : lance le hook s'il est déclaré. Il voit
# repo, plugin_dir, et note() pour un avertissement qui n'est pas une erreur.
plugin_hook() {
  local p=$1 hook=$2 f=$plugins_root/$1/setup.sh
  [ -f "$f" ] || return 0
  (
    plugin_dir=$plugins_root/$p
    note() { printf 'note    plugin %s : %s\n' "$p" "$*"; }
    # shellcheck source=/dev/null
    . "$f"
    declare -F "$hook" >/dev/null || exit 0
    "$hook"
  )
}

installed_json='[]'
refresh_installed() { installed_json=$(claude plugin list --json 2>/dev/null || echo '[]'); }
plugin_version() {
  jq -r --arg id "$1@$marketplace" '.[] | select(.id == $id) | .version // "?"' <<< "$installed_json"
}

ensure_marketplace() {
  if claude plugin marketplace list 2>/dev/null | grep -q "$marketplace"; then
    claude plugin marketplace update "$marketplace"
  else
    claude plugin marketplace add "$repo"
  fi
}

# Profil de référence (~/.claude/settings.json, lien vers home/.claude/settings.json versionné) :
# claude plugin y écrit (extraKnownMarketplaces, model, enabledPlugins). On le garde tel qu'il
# était avant l'appel ; seule exception, un plugin installé sans entrée dans enabledPlugins y
# est activé, comme le ferait claude plugin install. L'activation par profil reste à claude-profile.
settings_snap="" settings_added='[]'
settings_save() {
  [ -f "$settings" ] || return 0
  settings_snap=$(mktemp)
  cat "$settings" > "$settings_snap"
}
settings_restore() {
  local tmp
  [ -f "$settings" ] || return 0
  tmp=$(mktemp)
  if [ -n "$settings_snap" ]; then
    jq --argjson added "$settings_added" 'reduce $added[] as $p (.; .enabledPlugins[$p] //= true)' "$settings_snap" > "$tmp"
  else
    jq --arg m "$marketplace" 'del(.extraKnownMarketplaces[$m]) | if .extraKnownMarketplaces == {} then del(.extraKnownMarketplaces) else . end' \
      "$settings" > "$tmp"
  fi
  cmp -s "$tmp" "$settings" || cat "$tmp" > "$settings"   # à travers le lien, jamais de mv
  rm -f "$tmp" "$settings_snap"
}

install_one() {
  local p=$1 id=$1@$marketplace src dst rc=0
  printf '== plugin %s\n' "$p"
  if [ -n "$(plugin_version "$p")" ]; then
    claude plugin update "$id" || rc=1
  else
    claude plugin install "$id" || rc=1
  fi
  while IFS=$'\t' read -r src dst; do
    link_one "$src" "$dst" "${dst/#$dst_root/\~}"
  done < <(plugin_links "$p")
  plugin_hook "$p" on_install || { echo "on_install de $p en échec"; rc=1; }
  return $rc
}

# Profils (référence compris) qui activent encore un plugin retiré : à régler par claude-profile.
still_enabled() {
  local id=$1@$marketplace f n
  # La référence est lue dans sa copie : claude plugin uninstall vient d'en retirer l'entrée,
  # remise à la fin de l'appel.
  for f in "$settings_snap" "$repo"/profiles/*.json; do
    [ -f "$f" ] && jq -e --arg id "$id" '.enabledPlugins[$id] == true' "$f" >/dev/null 2>&1 || continue
    if [ "$f" = "$settings_snap" ]; then n=reference; else n=$(basename "$f" .json); fi
    printf '        encore activé dans %s : claude-profile plugin %s %s off (ou /profile show %s)\n' "$n" "$n" "$id" "$n"
  done
}

remove_one() {
  local p=$1 id=$1@$marketplace src dst rc=0
  printf '== plugin %s (retrait)\n' "$p"
  plugin_hook "$p" on_remove || rc=1
  while IFS=$'\t' read -r src dst; do
    if same_target "$dst" "$src"; then
      rm "$dst"; printf 'unlink  %s\n' "${dst/#$dst_root/\~}"
    elif [ -e "$dst" ] || [ -L "$dst" ]; then
      printf 'gardé   %s (ne pointe pas vers le plugin)\n' "${dst/#$dst_root/\~}"
    fi
  done < <(plugin_links "$p")
  if [ -n "$(plugin_version "$p")" ]; then
    claude plugin uninstall "$id" || rc=1
  else
    printf 'absent  plugin %s (pas installé)\n' "$p"
  fi
  still_enabled "$p"
  return $rc
}

# État des plugins : installé et à jour (aucun commit sur plugins/<p> depuis la version installée,
# le SHA du dépôt à l'install/update), liens déclarés, on_status. Un plugin absent n'est pas une erreur.
plugins_status() {
  local p v src dst out d rc=0
  if ! command -v claude >/dev/null 2>&1; then echo "claude absent : plugins non vérifiés"; return 0; fi
  refresh_installed
  for p in $(plugin_names); do
    v=$(plugin_version "$p")
    if [ -z "$v" ]; then
      printf 'absent  plugin %s\n' "$p"; continue
    elif git -C "$repo" cat-file -e "$v^{commit}" 2>/dev/null && git -C "$repo" diff --quiet "$v" HEAD -- "plugins/$p"; then
      printf 'ok      plugin %s (%s)\n' "$p" "$v"
    else
      printf 'UPDATE  plugin %s (installé %s, modifié depuis : ./install.sh plugin %s)\n' "$p" "$v" "$p"; rc=1
    fi
    while IFS=$'\t' read -r src dst; do
      if same_target "$dst" "$src"; then
        printf 'ok      plugin %s : %s\n' "$p" "${dst/#$dst_root/\~}"
      elif [ -L "$dst" ]; then
        printf 'WRONG   plugin %s : %s -> %s\n' "$p" "${dst/#$dst_root/\~}" "$(readlink "$dst")"; rc=1
      elif [ -e "$dst" ]; then
        printf 'DIFF    plugin %s : %s (fichier normal, ./install.sh plugin %s le sauvegarde)\n' "$p" "${dst/#$dst_root/\~}" "$p"; rc=1
      else
        printf 'MISSING plugin %s : %s\n' "$p" "${dst/#$dst_root/\~}"; rc=1
      fi
    done < <(plugin_links "$p")
    for d in $(plugin_deps "$p"); do
      [ -n "$(plugin_version "$d")" ] || { printf 'MISSING plugin %s : dépendance %s (./install.sh plugin %s)\n' "$p" "$d" "$d"; rc=1; }
    done
    if ! out=$(plugin_hook "$p" on_status); then
      printf 'ERREUR  plugin %s : %s\n' "$p" "$out"; rc=1
    elif [ -n "$out" ]; then
      printf '%s\n' "$out"
    fi
  done
  return $rc
}

cmd_plugin() {
  local remove=0 all=0 p rc=0
  local -a names=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --remove) remove=1 ;;
      --all) all=1 ;;
      -*) usage; exit 2 ;;
      *) names+=("$1") ;;
    esac
    shift
  done
  if [ $all = 0 ] && [ ${#names[@]} = 0 ]; then
    [ $remove = 0 ] || { usage; exit 2; }
    plugins_status; return
  fi
  command -v claude >/dev/null 2>&1 || { echo "claude absent : plugins ignorés"; return 0; }
  command -v jq >/dev/null 2>&1 || { echo "jq requis pour les plugins" >&2; return 1; }
  [ $all = 1 ] && mapfile -t names < <(plugin_names)
  # À l'installation, les dépendances passent d'abord (avec leurs liens ; claude plugin install
  # les installerait de toute façon, mais sans ce que pose leur setup.sh).
  [ $remove = 1 ] || mapfile -t names < <(with_deps "${names[@]}")
  for p in "${names[@]}"; do
    grep -qx -- "$p" < <(plugin_names) || { printf 'plugin inconnu : %s (plugins : %s)\n' "$p" "$(plugin_names | tr '\n' ' ')" >&2; return 2; }
  done

  sweep_orphans
  settings_save
  trap settings_restore EXIT
  ensure_marketplace
  refresh_installed
  for p in "${names[@]}"; do
    if [ $remove = 1 ]; then
      remove_one "$p" || rc=1
    else
      jq -e --arg id "$p@$marketplace" '(.enabledPlugins // {}) | has($id)' "$settings_snap" >/dev/null 2>&1 \
        || settings_added=$(jq -c --arg id "$p@$marketplace" '. + [$id]' <<< "$settings_added")
      install_one "$p" || rc=1
    fi
  done
  settings_restore; trap - EXIT

  # Dépendances retirées avec rien : on les garde, en disant si plus rien n'en a besoin.
  if [ $remove = 1 ]; then
    refresh_installed
    local d q needed
    for d in $(for p in "${names[@]}"; do plugin_deps "$p"; done | sort -u); do
      [ -n "$(plugin_version "$d")" ] || continue
      needed=""
      for q in $(plugin_names); do
        [ -n "$(plugin_version "$q")" ] && plugin_deps "$q" | grep -qx -- "$d" && needed+=" $q"
      done
      if [ -z "$needed" ]; then
        printf 'note    plugin %s gardé, plus aucun plugin n'"'"'en dépend : ./install.sh plugin --remove %s\n' "$d" "$d"
      fi
    done
  fi

  # Dossiers de profil régénérés (settings.json = référence + surcharge, liens à jour).
  refresh_installed
  if [ -n "$(plugin_version profiles)" ]; then
    "$plugins_root/profiles/bin/claude-profile" generate --all || rc=1
  fi
  return $rc
}

cmd_status() {
  local rel src dst rc=0 l
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
  while IFS= read -r l; do
    printf 'ORPHAN  %s -> %s (lien mort vers le dépôt : ./install.sh link le retire)\n' "${l#"$dst_root"/}" "$(readlink "$l")"; rc=1
  done < <(orphans)
  plugins_status || rc=1
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
  all)     cmd_link; cmd_plugin --all; cmd_setup ;;
  link)    cmd_link ;;
  setup)   cmd_setup ;;
  plugin)  shift; cmd_plugin "$@" ;;
  status)  cmd_status ;;
  adopt)   shift; [ $# -gt 0 ] || { usage; exit 2; }; cmd_adopt "$@" ;;
  capture) shift; [ $# -gt 0 ] || { usage; exit 2; }; cmd_capture "$@" ;;
  *)       usage; exit 2 ;;
esac
