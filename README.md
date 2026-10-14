# claude-tools

Configuration locale versionnée de mes outils de développement assisté par IA :
[Claude Code](https://code.claude.com/docs) (settings, status line, notifications desktop,
skills), [herdr](https://herdr.dev), l'extension GNOME `claude-notify` et les outils
`mise` globaux — appliquée dans `$HOME` par symlinks via `install.sh`.
Le détail de chaque outil (fonctionnalités, prérequis, installation, configuration
spécifique) est dans [TOOLS.md](TOOLS.md) ; les outils shell hors Claude (`gpr`, `gbr`) dans
[SHELL.md](SHELL.md).

## Installer

Tout d'un coup (liens + scripts `setup/`) :

```bash
git clone git@github.com:yoannwicker/claude-tools.git ~/workspace_perso/claude-tools
cd ~/workspace_perso/claude-tools && ./install.sh
```

À la carte :

| Outil | Commande | Prérequis |
|---|---|---|
| Claude Code (settings, status line, règles, skills `/pr`, `/br`, `/worktree`) | `./install.sh link` | `claude` installé et connecté, `jq`, `python3`, `gh` authentifié |
| mise (outils globaux) | `./setup/10-mise.sh` | `curl` |
| herdr (+ intégrations Claude/Copilot) | `./setup/20-herdr.sh` | `curl` ; Linux ou macOS |
| Notifications desktop (hooks + extension GNOME) | `./install.sh link && ./setup/30-gnome.sh` | GNOME Shell 46, `python3-gi`, `gdbus`, `xprop`, gnome-terminal |
| Lanceur `cl` (choix des espaces de travail) | `./install.sh link && ./setup/50-cl.sh` | `claude` |
| Plugins `pr-comments` (fils de review non résolus) et `intellij` (MCP IntelliJ + consigne) | `./setup/60-plugins.sh` | `claude` ≥ 2.1.287, `gh` authentifié, `jq` ; IntelliJ avec le serveur MCP sur le port 64342 |

Sans GNOME : garder `./install.sh link` et retirer les hooks `notify.sh` de
`home/.claude/settings.json` (événements `Stop`, `StopFailure`, `Notification`,
`UserPromptSubmit`). Le premier `enable` d'une extension GNOME fraîchement liée peut
demander une déconnexion/reconnexion de session.

## Au quotidien

- `git status` dans ce repo montre ce qui a changé dans ma config (les fichiers de
  `$HOME` sont des liens vers `home/`) : relire, committer.
- `cl <projet> [args claude…]` (lié dans `~/.local/bin`) : ouvre Claude Code sur un
  projet des espaces de travail choisis à l'installation (nom exact, sinon partiel
  insensible à la casse, sinon menu). `cl --list | --add [chemin] | --remove <n>` pour les
  faire évoluer, `cl --setup` pour refaire la sélection.
- Fils de review non résolus de mes PR (et de celles que je relis) : ligne `💬` au-dessus
  du prompt, `c` ou `/pr-review` pour les parcourir, les envoyer à Claude, répondre,
  résoudre (plugin `pr-comments`).
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
  .bash_aliases     charge .config/shell/*.sh (outils shell, voir SHELL.md)
  .claude/          settings.json, statusline-*.sh, notify*.sh, claude-notify.py, rules/, skills/{pr,br,worktree}/
  .config/          herdr/config.toml, mise/config.toml, shell/git-tools.sh
  .local/           bin/{cl,dot,gpr,gbr}, lib/git-tools.sh, share/gnome-shell/extensions/claude-notify@ywicker/
.claude-plugin/     marketplace.json : ce dépôt comme marketplace locale « claude-tools »
plugins/            plugins Claude Code : pr-comments/ (repris d'aguiddir/claude-config), intellij/
setup/              scripts idempotents : 10-mise, 20-herdr, 30-gnome, 50-cl, 60-plugins
TOOLS.md            détail par outil
SHELL.md            outils shell hors Claude (gpr, gbr)
AGENTS.md           consignes pour les agents (CLAUDE.md l'importe)
```
