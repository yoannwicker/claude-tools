# plugins/session-analysis/setup.sh — AgentsView, outil externe dont dépendent les skills.
# Lu (sourcé) par ./install.sh plugin session-analysis (format : CLAUDE-CODE.md, Plugins).
on_install() {
  command -v agentsview >/dev/null 2>&1 && return 0
  command -v curl >/dev/null 2>&1 || { note "curl absent : installer AgentsView à la main (https://agentsview.io)"; return 0; }
  # installeur officiel : dernière version, somme SHA-256 vérifiée, binaire dans ~/.local/bin
  # (ou /usr/local/bin s'il est inscriptible)
  curl -fsSL https://agentsview.io/install.sh | bash \
    || note "installation d'AgentsView échouée : curl -fsSL https://agentsview.io/install.sh | bash"
}

on_remove() {
  command -v agentsview >/dev/null 2>&1 \
    && note "AgentsView reste installé ($(command -v agentsview)) : agentsview daemon stop, puis supprimer le binaire et ~/.agentsview"
  return 0
}

on_status() {
  command -v agentsview >/dev/null 2>&1 \
    || { note "agentsview absent du PATH : ./install.sh plugin session-analysis l'installe"; return 0; }
  agentsview serve status 2>/dev/null | grep -q '^agentsview running' \
    || note "AgentsView ne tourne pas : les skills le lancent (agentsview daemon start)"
  return 0
}
