# plugins/review/setup.sh — profil Herdr UI facultatif (herdr/profile.sh) et review-watch
# (lien dans ~/.local/bin, unités systemd utilisateur). Lu (sourcé) par
# ./install.sh plugin review (format : CLAUDE-CODE.md, Plugins).
links=(                                                  # <chemin dans le plugin>  <destination>
  # chemin fixe pour le timer systemd et les clics de notification (hors de Claude)
  "bin/review-watch              ~/.local/bin/review-watch"
  "systemd/review-watch.service  ~/.config/systemd/user/review-watch.service"
  "systemd/review-watch.timer    ~/.config/systemd/user/review-watch.timer"
  # déclaration auprès de gh-watch (supervision : gh-watch status, /gh-watch:auto-status)
  "bin/review-watch              ~/.config/claude-tools/watchers.d/review-watch"
)
on_install() {
  "$plugin_dir/herdr/profile.sh" install
  # la surveillance reste à activer : review-watch enable (ou /review:pr-auto)
  command -v systemctl >/dev/null 2>&1 && systemctl --user daemon-reload 2>/dev/null || true
}
on_remove() {
  "$plugin_dir/herdr/profile.sh" remove
  # systemd --user ne connaît que le vrai HOME : sur un HOME de test, ne pas arrêter (ni
  # délier) le timer de la session
  if command -v systemctl >/dev/null 2>&1 && [ "$(systemctl --user show -p FragmentPath --value review-watch.timer 2>/dev/null)" \
       = "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/review-watch.timer" ]; then
    systemctl --user disable --now review-watch.timer 2>/dev/null || true
  fi
  rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/review-watch.timer.d"   # review-watch interval
}
on_status() {
  local out
  out=$("$plugin_dir/herdr/profile.sh" status)
  [ -z "$out" ] || note "$out"
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/claude-tools/review.json"
  if [ -f "$cfg" ] && grep -q '"on_[a-z_]*": *"\(auto\|notify\)"' "$cfg" && command -v systemctl >/dev/null 2>&1 \
     && ! systemctl --user is-active --quiet review-watch.timer 2>/dev/null; then
    note "review-watch configuré mais arrêté : review-watch enable"
  fi
  return 0
}
