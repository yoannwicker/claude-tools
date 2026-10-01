# claude-tools

Configuration locale versionnée de mes outils de développement assisté par IA :
[Claude Code](https://code.claude.com/docs) (settings, status line, notifications desktop,
skills), [herdr](https://herdr.dev), l'extension GNOME `claude-notify` et les outils
`mise` globaux — appliquée dans `$HOME` par symlinks via `install.sh`.
Le détail de chaque outil (fonctionnalités, prérequis, installation, configuration
spécifique) est dans [TOOLS.md](TOOLS.md).

## Installer

Tout d'un coup (liens + scripts `setup/`) :

```bash
git clone git@github.com:yoannwicker/claude-tools.git ~/workspace_perso/claude-tools
cd ~/workspace_perso/claude-tools && ./install.sh
```

À la carte :

| Outil | Commande | Prérequis |
|---|---|---|
| Claude Code (settings, status line, skills `/pr`, `/worktree`) | `./install.sh link` | `claude` installé et connecté, `jq`, `python3`, `gh` authentifié |
| mise (outils globaux) | `./setup/10-mise.sh` | `curl` |
| herdr (+ intégrations Claude/Copilot) | `./setup/20-herdr.sh` | `curl` ; Linux ou macOS |
| Notifications desktop (hooks + extension GNOME) | `./install.sh link && ./setup/30-gnome.sh` | GNOME Shell 46, `python3-gi`, `gdbus`, `xprop`, gnome-terminal |
| MCP IntelliJ | `./setup/40-mcp.sh` | `claude`, IntelliJ avec le serveur MCP sur le port 64342 |

Sans GNOME : garder `./install.sh link` et retirer les hooks `notify.sh` de
`home/.claude/settings.json` (événements `Stop`, `StopFailure`, `Notification`,
`UserPromptSubmit`). Le premier `enable` d'une extension GNOME fraîchement liée peut
demander une déconnexion/reconnexion de session.

## Au quotidien

- `git status` dans ce repo montre ce qui a changé dans ma config (les fichiers de
  `$HOME` sont des liens vers `home/`) : relire, committer.
- `dot` (lié dans `~/.local/bin`) : dérive git, état des liens, `mise upgrade`,
  `herdr update`, `claude update`.
- `./install.sh adopt <fichier>` : versionner un nouveau fichier de `$HOME` (déplacé dans
  `home/`, remplacé par un lien). `./install.sh status` : état de chaque fichier géré.
- `./install.sh capture <fichier>` : repli pour un fichier qu'un outil réécrit en
  remplaçant le lien (recopie `$HOME` → `home/`).

## Ne jamais ajouter

`~/.claude/.credentials.json`, `~/.claude.json` (tokens OAuth, état, serveurs MCP
utilisateur), `~/.claude/projects/` (transcripts, mémoire), `~/.claude/plugins/`,
`~/.claude/skills/synced/`, `history.jsonl`, et dans `~/.config/herdr/` les `*.log`,
`*.sock`, `session.json`. Toujours `adopt` fichier par fichier, jamais un dossier.

## Structure

```
install.sh          link | setup | status | adopt | capture (défaut : link + setup)
home/               miroir de $HOME, un lien par fichier
  .claude/          settings.json, statusline-*.sh, notify*.sh, claude-notify.py, skills/{pr,worktree}/
  .config/          herdr/config.toml, mise/config.toml
  .local/           bin/dot, share/gnome-shell/extensions/claude-notify@ywicker/
setup/              scripts idempotents : 10-mise, 20-herdr, 30-gnome, 40-mcp
TOOLS.md            détail par outil
```
