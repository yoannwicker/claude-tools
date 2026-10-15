#!/usr/bin/env bash
# Notifications desktop : active l'extension GNOME claude-notify@ywicker et vérifie ses dépendances.
set -eu
uuid=claude-notify@ywicker
if ! command -v gnome-extensions >/dev/null 2>&1; then
  echo "gnome-extensions absent : pas de GNOME Shell, notifications desktop ignorées"
  exit 0
fi
missing=""
command -v gdbus >/dev/null 2>&1 || missing="$missing gdbus"
command -v xprop >/dev/null 2>&1 || missing="$missing xprop"
command -v jq >/dev/null 2>&1 || missing="$missing jq"
python3 -c 'import gi; gi.require_version("Notify", "0.7"); from gi.repository import Notify' 2>/dev/null \
  || missing="$missing python3-gi(Notify)"
[ -z "$missing" ] || echo "dépendances manquantes pour les notifications :$missing"
[ -e "$HOME/.local/bin/claude-notify-click" ] \
  || echo "~/.local/bin/claude-notify-click absent (script de clic du plugin notify) : lancer setup/60-plugins.sh"

if gnome-extensions info "$uuid" 2>/dev/null | grep -q "ACTIVE"; then
  echo "extension $uuid : active"
elif gnome-extensions enable "$uuid" 2>/dev/null; then
  echo "extension $uuid : activée"
else
  echo "extension $uuid non visible par GNOME Shell : se déconnecter/reconnecter puis relancer ce script"
fi
