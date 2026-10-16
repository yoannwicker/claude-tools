# plugins/build-brief/setup.sh — contrôle hors du plugin. Lu (sourcé) par
# ./install.sh plugin build-brief (format : CLAUDE-CODE.md, Plugins).
on_status() {
  command -v build-brief >/dev/null 2>&1 || note "build-brief absent du PATH : le garde-fou laisse passer Gradle brut"
}
