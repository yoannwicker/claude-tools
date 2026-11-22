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
  || echo "~/.local/bin/claude-notify-click absent (script de clic du plugin notify) : lancer ./install.sh plugin notify"

info=$(gnome-extensions info "$uuid" 2>/dev/null || true)
if grep -q "OUT OF DATE" <<<"$info"; then
  major=$(gnome-shell --version | grep -oE '[0-9]+' | head -1)
  if jq -e --arg v "$major" '."shell-version" | index($v)' \
      "$HOME/.local/share/gnome-shell/extensions/$uuid/metadata.json" >/dev/null 2>&1; then
    echo "extension $uuid : GNOME Shell $major ajouté à shell-version, pris en compte au prochain login"
  else
    echo "extension $uuid non chargée : GNOME Shell $major absent de shell-version (metadata.json) ;" \
      "l'ajouter puis se déconnecter/reconnecter"
  fi
elif grep -q "ERROR" <<<"$info"; then
  echo "extension $uuid en erreur (API GNOME changée ?) : journalctl --user -b | grep claude-notify"
elif grep -q "ACTIVE" <<<"$info"; then
  echo "extension $uuid : active"
elif gnome-extensions enable "$uuid" 2>/dev/null; then
  echo "extension $uuid : activée"
else
  echo "extension $uuid non visible par GNOME Shell : se déconnecter/reconnecter puis relancer ce script"
fi
