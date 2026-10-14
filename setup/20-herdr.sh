#!/usr/bin/env bash
# herdr : installe le binaire si absent, pose les intégrations agents, nettoie le hook Claude.
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

# `herdr integration install claude` ajoute un hook SessionStart avec un chemin absolu.
# Les profils (profiles/*.json) portent déjà la variante portable ($HOME + garde [ -f … ]) :
# on retire les doublons absolus, en écrivant à travers le lien (jamais de mv).
settings=$HOME/.claude/settings.json
if [ -f "$settings" ] && command -v python3 >/dev/null 2>&1; then
  python3 - "$settings" <<'PY'
import json, re, sys
p = sys.argv[1]
d = json.load(open(p))
pat = re.compile(r"^bash '.*herdr-agent-state\.sh' session$")
ss = d.get("hooks", {}).get("SessionStart", [])
before = sum(len(e["hooks"]) for e in ss)
for e in ss:
    e["hooks"] = [h for h in e["hooks"] if not pat.match(h.get("command", ""))]
ss = [e for e in ss if e["hooks"]]
after = sum(len(e["hooks"]) for e in ss)
if before != after:
    d["hooks"]["SessionStart"] = ss
    with open(p, "w") as f:
        json.dump(d, f, indent=2, ensure_ascii=False); f.write("\n")
    print(f"hook herdr absolu retiré de settings.json ({before - after})")
PY
fi
