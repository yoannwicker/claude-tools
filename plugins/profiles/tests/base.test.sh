#!/usr/bin/env bash
# Tests des profils avec base de claude-profile : bash plugins/profiles/tests/base.test.sh
# HOME jetable, copie de claude-profile dans un faux dépôt (profiles/), dépôt de base local dont
# l'installeur écrit sa config dans $HOME/.claude ; faux claude dans le PATH (appels notés).
set -u
src=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/claude-profile
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0
export HOME=$tmp/home
unset CLAUDE_CONFIG_DIR
cp_=$tmp/tools/plugins/profiles/bin/claude-profile
mkdir -p "$(dirname "$cp_")" "$tmp/tools/profiles" "$tmp/fake" "$HOME/.claude/projects" "$HOME/.claude/rules" "$HOME/.claude-profiles"
cp "$src" "$cp_"
echo '[]' > "$HOME/.claude-profiles/.mcp-servers.json"

ok() { printf 'ok    %s\n' "$1"; }
ko() { printf 'FAIL  %s\n%s\n' "$1" "${2:-}"; fails=$((fails + 1)); }
# expect <code> <texte attendu> <args de claude-profile…>
expect() {
  local code=$1 text=$2 out got
  shift 2
  out=$(PATH=$tmp/fake:$PATH "$cp_" "$@" 2>&1); got=$?
  if [ "$got" = "$code" ] && printf '%s' "$out" | grep -qF -- "$text"; then ok "$* → $text"; else ko "$* (code $got)" "$out"; fi
}
# check <description> <commande de test…>
check() { local d=$1; shift; if "$@"; then ok "$d"; else ko "$d"; fi; }
settings() { jq -c "$1" "$HOME/.claude-profiles/vidal/settings.json"; }

# Faux claude : note ses appels ; plugin install <p> l'ajoute aux plugins installés du HOME courant.
cat > "$tmp/fake/claude" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$CALLS"
if [ "$1 $2" = "plugin install" ]; then
  f=$HOME/.claude/plugins/installed_plugins.json
  jq --arg p "$3" '.plugins[$p] = [{installPath: "/nulle/part"}]' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  jq --arg p "$3" '.enabledPlugins[$p] = true' "$HOME/.claude/settings.json" > "$HOME/s.tmp" && mv "$HOME/s.tmp" "$HOME/.claude/settings.json"
fi
EOF
chmod +x "$tmp/fake/claude"
export CALLS=$tmp/calls
: > "$CALLS"

# Référence : ~/.claude avec sa config (rules, CLAUDE.md) et une marketplace m connue.
echo '{"enabledPlugins": {"mine@m": true}, "model": "opus"}' > "$HOME/.claude/settings.json"
echo moi > "$HOME/.claude/CLAUDE.md"
mkdir -p "$HOME/.claude/plugins"
echo '{"version": 2, "plugins": {}}' > "$HOME/.claude/plugins/installed_plugins.json"
echo "{\"m\": {\"source\": {\"source\": \"directory\", \"path\": \"$tmp/m\"}}}" > "$HOME/.claude/plugins/known_marketplaces.json"

# Dépôt de base : son installeur active h@h (qui dépend de d@h) et b@h, avec CLAUDE.md et skills.
git init -q -b main "$tmp/harnais"
cat > "$tmp/harnais/install.sh" <<'EOF'
c=$HOME/.claude
mkdir -p "$c/plugins/h/.claude-plugin" "$c/plugins/d" "$c/skills/s"
echo '{"name": "h", "dependencies": ["d"]}' > "$c/plugins/h/.claude-plugin/plugin.json"
plugins=$(cat "$(dirname "$0")/plugins")
jq -n --arg c "$c" --argjson on "$plugins" '{version: 2, plugins: ($on | map({(.): [{installPath: "\($c)/plugins/\(split("@")[0])"}]}) | add + {"d@h": [{installPath: "\($c)/plugins/d"}]})}' \
  > "$c/plugins/installed_plugins.json"
echo '{}' > "$c/plugins/known_marketplaces.json"
jq -n --argjson on "$plugins" '{enabledPlugins: ($on | map({(.): true}) | add), statusLine: {type: "command", command: "harnais"}}' > "$c/settings.json"
echo harnais > "$c/CLAUDE.md"
EOF
echo '["h@h", "b@h"]' > "$tmp/harnais/plugins"
git -C "$tmp/harnais" add -A && git -C "$tmp/harnais" -c user.name=t -c user.email=t@t commit -qm init

cat > "$tmp/tools/profiles/vidal.json" <<EOF
{ "description": "harnais", "base": { "repo": "$tmp/harnais", "install": "install.sh" } }
EOF

echo '{"enabledPlugins": {"mine@m": true}}' > "$tmp/tools/profiles/lean.json"
expect 2 'profil sans base : lean' base lean
expect 0 'généré : lean' generate lean
check 'profil sans base : inchangé (référence, CLAUDE.md, rules)' \
  test "$(jq -r .model "$HOME/.claude-profiles/lean/settings.json")" = opus -a "$(cat "$HOME/.claude-profiles/lean/CLAUDE.md")" = moi -a -d "$HOME/.claude-profiles/lean/rules"
expect 2 'base absente pour vidal' generate vidal
expect 0 'base installée' base vidal update
check 'base : settings.json retenu' test -f "$HOME/.claude-profiles/.bases/vidal/settings.json"
check 'base : outils de la machine liés au vrai HOME' test "$(readlink -f "$HOME/.claude-profiles/.bases/vidal/home/.local")" = "$HOME/.local"
check 'plugins de la base et dépendance actifs' test "$(settings '.enabledPlugins')" = '{"h@h":true,"b@h":true,"d@h":true}'
check 'réglages de la base, pas de la référence' test "$(settings '[.statusLine.command, .model]')" = '["harnais",null]'
d=$HOME/.claude-profiles/vidal
check 'CLAUDE.md et skills de la base' test "$(cat "$d/CLAUDE.md")" = harnais -a -d "$d/skills/s"
check 'plugins de la base' test "$(readlink -f "$d/plugins")" = "$HOME/.claude-profiles/.bases/vidal/home/.claude/plugins"
check 'transcripts communs avec ~/.claude' test "$(readlink -f "$d/projects")" = "$HOME/.claude/projects"
check 'rules de ~/.claude non repris' test ! -e "$d/rules"
expect 0 'plugins de la base :' show vidal
expect 0 '+ d@h (dépendance)' show vidal

expect 0 'b@h : désactivé dans vidal' plugin vidal b@h off
check 'plugin de la base coupé : base.disabledPlugins' test "$(jq -c '.base.disabledPlugins' "$tmp/tools/profiles/vidal.json")" = '["b@h"]'
check 'plugin de la base coupé : false' test "$(settings '.enabledPlugins["b@h"]')" = false
expect 0 '- b@h (coupé par le profil)' show vidal
expect 0 'b@h : activé dans vidal' plugin vidal b@h on
check 'plugin de la base réactivé : retiré de la liste' test "$(jq -c '.base.disabledPlugins' "$tmp/tools/profiles/vidal.json")" = '[]'
expect 0 'il ne se chargera pas' plugin vidal d@h off
expect 0 'd@h : activé' plugin vidal d@h on

# Plugin du profil : installé dans la base depuis la marketplace de ~/.claude, hors des plugins de la base.
expect 0 'a@m : activé dans vidal' plugin vidal a@m on
check 'marketplace ajoutée dans la base' grep -qxF "plugin marketplace add $tmp/m" "$CALLS"
check 'plugin installé dans la base' grep -qxF 'plugin install a@m' "$CALLS"
check 'plugin du profil ajouté aux plugins de la base' test "$(settings '.enabledPlugins["a@m"]')" = true
check "plugin du profil absent des plugins de la base" \
  test "$(jq -c '.enabledPlugins | has("a@m")' "$HOME/.claude-profiles/.bases/vidal/home/.claude/settings.json")" = false
expect 0 '+ a@m' show vidal

# Mise à jour de la base : un plugin ajouté par le dépôt est actif sans toucher au profil.
echo '["h@h", "b@h", "n@h"]' > "$tmp/harnais/plugins"
git -C "$tmp/harnais" -c user.name=t -c user.email=t@t commit -qam n
expect 0 '+ n@h' base vidal update
check 'nouveau plugin de la base actif' test "$(settings '.enabledPlugins["n@h"]')" = true
expect 0 'version :' base vidal
jq '.enabledPlugins["h@h"] = true' "$tmp/tools/profiles/vidal.json" > "$tmp/v" && mv "$tmp/v" "$tmp/tools/profiles/vidal.json"
expect 0 'déjà actif dans la base' generate vidal

[ "$fails" -eq 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
