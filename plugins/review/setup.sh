# plugins/review/setup.sh — profil Herdr UI facultatif (herdr/profile.sh). Lu (sourcé) par
# ./install.sh plugin review (format : CLAUDE-CODE.md, Plugins).
on_install() { "$plugin_dir/herdr/profile.sh" install; }
on_remove() { "$plugin_dir/herdr/profile.sh" remove; }
on_status() {
  local out
  out=$("$plugin_dir/herdr/profile.sh" status)
  [ -z "$out" ] || note "$out"
}
