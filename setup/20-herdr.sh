#!/usr/bin/env bash
# herdr : installe le binaire si absent, propose l'interface (terminal seul, ou avec Herdr UI),
# pose les intégrations agents, retire le hook Claude de settings.json (il vient du plugin
# herdr-session, quand celui-ci est installé).
#   --ui  installe Herdr UI sans demander (et oublie un refus)
# Le choix est demandé dans un terminal tant que Herdr UI n'est ni installé ni refusé ; un refus est
# retenu (~/.config/claude-tools/herdr-ui-declined). Sans terminal, il est seulement signalé.
set -eu
if ! command -v herdr >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/herdr" ]; then
  curl -fsSL https://herdr.dev/install.sh | sh
fi
herdr=$(command -v herdr || echo "$HOME/.local/bin/herdr")

# Herdr UI (penso/herdr-gpui) : client graphique tiers, branché sur le serveur herdr local. Il se met
# à jour lui-même (panneau App Updates).
herdr_ui() {
  local declined=${XDG_CONFIG_HOME:-$HOME/.config}/claude-tools/herdr-ui-declined glibc answer
  if command -v herdr-gpui >/dev/null 2>&1; then
    echo "interface : terminal + Herdr UI (mis à jour par l'app)"
    return 0
  fi
  case $(uname -s) in
    Linux)
      glibc=$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')
      if [ -z "$glibc" ] || [ "$(printf '%s\n2.39\n' "$glibc" | sort -V | head -1)" != 2.39 ]; then
        echo "interface : terminal (Herdr UI demande glibc ≥ 2.39, ici ${glibc:-inconnue})"
        return 0
      fi ;;
    Darwin) ;;
    *) echo "interface : terminal (Herdr UI non disponible sur $(uname -s))"; return 0 ;;
  esac
  if [ "${1:-}" != --ui ]; then
    if [ -f "$declined" ] || [ ! -t 0 ]; then
      echo "interface : terminal (./setup/20-herdr.sh --ui pour ajouter Herdr UI)"
      return 0
    fi
    echo "Interface de herdr :"
    echo "  1) terminal seul (herdr)"
    echo "  2) terminal + graphique (Herdr UI, client tiers, demande sudo)"
    read -r -p "Choix [1] : " answer || answer=""
    if [ "$answer" != 2 ]; then
      mkdir -p "$(dirname "$declined")" && touch "$declined"
      echo "interface : terminal (./setup/20-herdr.sh --ui pour ajouter Herdr UI)"
      return 0
    fi
  fi
  rm -f "$declined"
  case $(uname -s) in
    Linux) curl -fsSL https://herdrui.dev/install.sh | sh ;;
    Darwin) brew install penso/tap/herdr-gpui ;;
  esac
}
herdr_ui "$@"

integrations="claude"
command -v copilot >/dev/null 2>&1 && integrations="$integrations copilot"
for agent in $integrations; do
  if "$herdr" integration status 2>/dev/null | grep -q "^$agent: current"; then
    echo "intégration herdr $agent : à jour"
  else
    "$herdr" integration install "$agent"
  fi
done

# `herdr integration install claude` ajoute à ~/.claude/settings.json un hook SessionStart vers
# son script, avec un chemin absolu. Le branchement vient du plugin herdr-session : s'il est installé,
# on retire de settings.json tout hook herdr (absolu ou ancienne variante portable des profils), en
# écrivant à travers le lien (jamais de mv). Sans le plugin, ce hook est le seul branchement herdr.
settings=$HOME/.claude/settings.json
if ! claude plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "herdr-session@claude-tools")' >/dev/null 2>&1; then
  echo "plugin herdr-session absent : hook herdr gardé dans settings.json (./install.sh plugin herdr-session pour passer par le plugin)"
elif [ -f "$settings" ] && command -v python3 >/dev/null 2>&1; then
  python3 - "$settings" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
hooks = d.get("hooks", {})
ss = hooks.get("SessionStart", [])
before = sum(len(e.get("hooks", [])) for e in ss)
for e in ss:
    e["hooks"] = [h for h in e.get("hooks", []) if "herdr-agent-state.sh" not in h.get("command", "")]
ss = [e for e in ss if e["hooks"]]
after = sum(len(e["hooks"]) for e in ss)
if before != after:
    if ss:
        hooks["SessionStart"] = ss
    else:
        hooks.pop("SessionStart", None)
    if not hooks:
        d.pop("hooks", None)
    with open(p, "w") as f:
        json.dump(d, f, indent=2, ensure_ascii=False); f.write("\n")
    print(f"hook herdr retiré de settings.json ({before - after}) : il vient du plugin herdr-session")
PY
fi
