#!/usr/bin/env bash
# herdr : installe le binaire si absent, propose l'app Herdr (interface graphique, en plus de
# herdr en terminal), pose les intégrations agents (claude, et copilot, cursor s'ils sont là),
# retire le hook Claude de settings.json (il vient du plugin herdr-session, quand celui-ci est
# installé).
#   --app  installe l'app Herdr sans demander (et oublie un refus)
# Le choix est demandé dans un terminal tant que l'app n'est ni installée ni refusée ; un refus est
# retenu (~/.config/claude-tools/herdr-app-declined). Sans terminal, il est seulement signalé.
set -eu
if ! command -v herdr >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/herdr" ]; then
  curl -fsSL https://herdr.dev/install.sh | sh
fi
herdr=$(command -v herdr || echo "$HOME/.local/bin/herdr")

# App Herdr (herdr-app ; ses terminaux vivent dans herdr-core, `hc`) : installeur officiel, sans
# sudo (~/.local/share/herdr-app, herdr-core si absent) ; ensuite l'app se met à jour elle-même.
# Rien à y poser : elle reconnaît Claude seule (OSC 7501), la reprise vient du plugin
# herdr-session.
herdr_app() {
  local declined=${XDG_CONFIG_HOME:-$HOME/.config}/claude-tools/herdr-app-declined answer
  if command -v herdr-app >/dev/null 2>&1 || [ -x "$HOME/.local/bin/herdr-app" ]; then
    echo "app Herdr : installée (mise à jour par l'app)"
    return 0
  fi
  case $(uname -s) in Linux|Darwin) ;; *) echo "app Herdr : non disponible sur $(uname -s)"; return 0 ;; esac
  if [ "${1:-}" != --app ]; then
    if [ -f "$declined" ] || [ ! -t 0 ]; then
      echo "app Herdr : absente (./setup/20-herdr.sh --app pour l'ajouter)"
      return 0
    fi
    read -r -p "Ajouter l'app Herdr (interface graphique de herdr) ? [o/N] " answer || answer=""
    case $answer in
      [oOyY]*) ;;
      *) mkdir -p "$(dirname "$declined")" && touch "$declined"
         echo "app Herdr : absente (./setup/20-herdr.sh --app pour l'ajouter)"
         return 0 ;;
    esac
  fi
  rm -f "$declined"
  curl -fsSL https://releases.herdr.dev/app/install.sh | sh
}
herdr_app "$@"

# Copie à la souris dans un pane shell : herdr passe par wl-copy sous Wayland, sinon par OSC 52,
# que gnome-terminal ignore. Sans wl-clipboard, la copie se perd sans erreur.
if [ "${XDG_SESSION_TYPE:-}" = wayland ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
  command -v wl-copy >/dev/null 2>&1 \
    || echo "wl-copy absent : la copie depuis herdr ne marchera pas (sudo apt install wl-clipboard)"
fi

integrations="claude"
command -v copilot >/dev/null 2>&1 && integrations="$integrations copilot"
# Cursor : son intégration (hook sessionStart dans ~/.cursor/hooks.json) signale la session à herdr, qui
# la reprend après un redémarrage ; herdr-session ne fait rien sous Cursor.
{ command -v cursor-agent || command -v cursor; } >/dev/null 2>&1 && integrations="$integrations cursor"
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
