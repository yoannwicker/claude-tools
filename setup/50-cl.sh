#!/usr/bin/env bash
# cl : choix des espaces de travail scannés, propres à chaque machine (~/.config/cl/workspaces, non versionné).
# Interactif : numéros pour cocher/décocher, chemin pour ajouter, Entrée pour valider.
# Sans terminal : garde la config existante, sinon coche les ~/workspace* trouvés.
set -eu
conf=${XDG_CONFIG_HOME:-$HOME/.config}/cl/workspaces

pretty() { case "$1" in "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac; }
expand() { case "$1" in "~") printf '%s' "$HOME" ;; "~/"*) printf '%s/%s' "$HOME" "${1#"~/"}" ;; *) printf '%s' "$1" ;; esac; }
count() { find "$1" -maxdepth 1 -mindepth 1 -type d ! -name '.*' 2>/dev/null | wc -l; }

existing=()
if [ -f "$conf" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%%#*}; line=${line%"${line##*[![:space:]]}"}; line=${line#"${line%%[![:space:]]*}"}
    [ -n "$line" ] && existing+=("$(expand "$line")")
  done < "$conf"
fi

# Candidats : config existante + dossiers de $HOME contenant au moins un dépôt git enfant.
cands=() checked=()
add_cand() {
  local c
  for c in "${cands[@]}"; do [ "$c" = "$1" ] && return 0; done
  cands+=("$1"); checked+=("$2")
}
for w in "${existing[@]}"; do add_cand "$w" 1; done
while IFS= read -r d; do
  case "$d" in "$HOME"/workspace*) on=1 ;; *) on=0 ;; esac
  [ ${#existing[@]} -gt 0 ] && on=0
  add_cand "$d" "$on"
done < <(find "$HOME" -mindepth 3 -maxdepth 3 -name .git -path "$HOME/[!.]*" -printf '%h\n' 2>/dev/null \
           | xargs -r -d '\n' -n1 dirname | LC_ALL=C sort -u)

write_conf() {
  local -a sel=(); local i
  for i in "${!cands[@]}"; do [ "${checked[$i]}" = 1 ] && sel+=("$(pretty "${cands[$i]}")"); done
  mkdir -p "$(dirname "$conf")"
  { echo "# Espaces de travail scannés par cl (un par ligne). Modifier : cl --add / --remove / --setup"
    [ ${#sel[@]} -gt 0 ] && printf '%s\n' "${sel[@]}"; } > "$conf"
  echo "cl : $(pretty "$conf")"
  [ ${#sel[@]} -gt 0 ] && printf '  %s\n' "${sel[@]}" || echo "  (aucun espace : cl --add <chemin>)"
}

if [ ! -t 0 ]; then
  [ ${#existing[@]} -gt 0 ] && { echo "cl : config existante gardée"; exit 0; }
  write_conf; exit 0
fi

while :; do
  echo
  echo "Espaces de travail scannés par cl :"
  for i in "${!cands[@]}"; do
    mark=' '; [ "${checked[$i]}" = 1 ] && mark=x
    if [ -d "${cands[$i]}" ]; then info="$(count "${cands[$i]}") projets"; else info=absent; fi
    printf '  %2d) [%s] %s  (%s)\n' $((i + 1)) "$mark" "$(pretty "${cands[$i]}")" "$info"
  done
  read -r -p "Numéros à (dé)cocher, chemin à ajouter, Entrée pour valider : " answer || answer=""
  [ -z "$answer" ] && break
  for tok in $answer; do
    if [[ $tok =~ ^[0-9]+$ ]] && [ "$tok" -ge 1 ] && [ "$tok" -le ${#cands[@]} ]; then
      i=$((tok - 1)); checked[$i]=$((1 - checked[$i]))
    else
      p=$(expand "$tok")
      if [ -d "$p" ]; then
        p=$(cd "$p" && pwd -P); before=${#cands[@]}
        add_cand "$p" 1
        if [ ${#cands[@]} -eq "$before" ]; then
          for i in "${!cands[@]}"; do [ "${cands[$i]}" = "$p" ] && checked[$i]=1; done
        fi
      else
        echo "  ignoré (pas un dossier ni un numéro) : $tok"
      fi
    fi
  done
done
write_conf
