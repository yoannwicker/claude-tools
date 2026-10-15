#!/usr/bin/env bash
# herdr : installe le binaire si absent, pose les intégrations agents, retire le hook Claude de
# settings.json (il vient du plugin herdr-session).
set -eu
if ! command -v herdr >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/herdr" ]; then
  curl -fsSL https://herdr.dev/install.sh | sh
fi
herdr=$(command -v herdr || echo "$HOME/.local/bin/herdr")

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
# son script, avec un chemin absolu. Le branchement vient du plugin herdr-session : on retire de
# settings.json tout hook herdr (absolu ou ancienne variante portable des profils), en écrivant
# à travers le lien (jamais de mv).
settings=$HOME/.claude/settings.json
if [ -f "$settings" ] && command -v python3 >/dev/null 2>&1; then
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
