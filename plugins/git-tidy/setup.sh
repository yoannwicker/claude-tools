# plugins/git-tidy/setup.sh — tidy-watch (mode auto de /git-tidy:approved-auto) : lien dans
# ~/.local/bin et unités systemd utilisateur. Lu (sourcé) par ./install.sh plugin git-tidy
# (format : CLAUDE-CODE.md, Plugins).
links=(                                                  # <chemin dans le plugin>  <destination>
  # chemin fixe pour le timer systemd et les clics de notification (hors de Claude)
  "bin/tidy-watch              ~/.local/bin/tidy-watch"
  "systemd/tidy-watch.service  ~/.config/systemd/user/tidy-watch.service"
  "systemd/tidy-watch.timer    ~/.config/systemd/user/tidy-watch.timer"
  # déclaration auprès de gh-watch (supervision : gh-watch status, /gh-watch:status)
  "bin/tidy-watch              ~/.config/claude-tools/watchers.d/tidy-watch"
)
on_install() {
  # la surveillance reste à activer : tidy-watch enable (ou /git-tidy:approved-auto)
  command -v systemctl >/dev/null 2>&1 && systemctl --user daemon-reload 2>/dev/null || true
}
on_remove() {
  # systemd --user ne connaît que le vrai HOME : sur un HOME de test, ne pas arrêter (ni
  # délier) le timer de la session
  if command -v systemctl >/dev/null 2>&1 && [ "$(systemctl --user show -p FragmentPath --value tidy-watch.timer 2>/dev/null)" \
       = "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/tidy-watch.timer" ]; then
    systemctl --user disable --now tidy-watch.timer 2>/dev/null || true
  fi
  rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/tidy-watch.timer.d"   # tidy-watch interval
}
on_status() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/claude-tools/git-tidy.json"
  if [ -f "$cfg" ] && grep -q '"approved": *"\(auto\|notify\)"' "$cfg" && command -v systemctl >/dev/null 2>&1 \
     && ! systemctl --user is-active --quiet tidy-watch.timer 2>/dev/null; then
    note "tidy-watch configuré mais arrêté : tidy-watch enable"
  fi
  return 0
}
