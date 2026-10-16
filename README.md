# claude-tools

Configuration locale versionnée de mes outils de développement assisté par IA :
[Claude Code](https://code.claude.com/docs) (settings, status line, notifications desktop,
skills), [herdr](https://herdr.dev), l'extension GNOME `claude-notify` et les outils
`mise` globaux — appliquée dans `$HOME` par symlinks via `install.sh`.
Le détail (fonctionnalités, prérequis, installation, configuration spécifique) est dans
[CLAUDE-CODE.md](CLAUDE-CODE.md) pour Claude Code et ses plugins, et dans
[TOOLS.md](TOOLS.md) pour les outils hors Claude (`cl`, extension GNOME, herdr, mise).

## Installer

Tout d'un coup (liens + scripts `setup/`) :

```bash
git clone git@github.com:yoannwicker/claude-tools.git ~/workspace_perso/claude-tools
cd ~/workspace_perso/claude-tools && ./install.sh
```

À la carte, Claude Code (détail : [CLAUDE-CODE.md](CLAUDE-CODE.md)) :

| Outil | Commande | Prérequis |
|---|---|---|
| Claude Code (settings, status line) | `./install.sh link` | `claude` installé et connecté, `jq`, `python3`, `gh` authentifié |
| Plugins `pr-comments` (fils de review non résolus), `intellij` (MCP IntelliJ + consigne), `profiles` (commande `/profile`), `git-nav` (skills `/pr`, `/br`, `/worktree` ; `gpr`, `gbr` liés dans `~/.local/bin` pour le terminal), `notify` (notifications desktop), `herdr-session` (reprise des sessions par herdr), `build-brief` (consigne et garde-fou Gradle) | `./setup/60-plugins.sh` | `claude` ≥ 2.1.287, `gh` authentifié, `jq`, `git` ; IntelliJ avec le serveur MCP sur le port 64342 ; `notify` : `python3-gi`, `gdbus`, `xprop`, gnome-terminal ; `build-brief` : `build-brief` dans le PATH, `python3` |
| Profils (commande `claude-profile`, fonction shell `claude`) | `./install.sh link && ./setup/60-plugins.sh` (lie `claude-profile` dans `~/.local/bin`, pose le profil par défaut `vidal` → `~/.claude/settings.json`) | `jq` |

À la carte, outils externes (détail : [TOOLS.md](TOOLS.md)) :

| Outil | Commande | Prérequis |
|---|---|---|
| mise (outils globaux) | `./setup/10-mise.sh` | `curl` |
| herdr (+ intégrations Claude/Copilot) | `./setup/20-herdr.sh` | `curl` ; Linux ou macOS |
| Lanceur `cl` (choix des espaces de travail) | `./install.sh link && ./setup/50-cl.sh` | `claude` |
| Extension GNOME `claude-notify` (pastille des notifications du plugin `notify`) | `./install.sh link && ./setup/60-plugins.sh && ./setup/30-gnome.sh` | GNOME Shell 46 |

Sans GNOME : désactiver le plugin `notify` dans chaque profil (`"notify@claude-tools": false`
dans `enabledPlugins` de `profiles/*.json`, ou `/profile show`). Le premier `enable` d'une extension GNOME fraîchement liée peut
demander une déconnexion/reconnexion de session.

## Au quotidien

- `git status` dans ce repo montre ce qui a changé dans ma config (les fichiers de
  `$HOME` sont des liens vers `home/`) : relire, committer.
- `cl <projet> [args claude…]` (lié dans `~/.local/bin`) : ouvre Claude Code sur un
  projet des espaces de travail choisis à l'installation (nom exact, sinon partiel
  insensible à la casse, sinon menu). `cl --list | --add [chemin] | --remove <n>` pour les
  faire évoluer, `cl --setup` pour refaire la sélection.
- Profils : `claude-profile switch <profil>` (ou `cl -P <profil> <projet>`) lance Claude sur
  `~/.claude-profiles/<profil>/`, généré depuis `~/.claude` avec pour `settings.json`
  `profiles/<profil>.json` ; `claude` seul est sur le profil par défaut (`vidal` à
  l'installation ; `claude-profile default <profil>`, `/profile default`). Dans une
  session, `/profile` propose la liste des profils et `/profile <profil>` relance la
  conversation dans ce profil ; `/profile show [<profil>]` montre ce qui y est actif et
  (dés)active ses plugins, `/profile create <nom>` crée un profil.
- Fils de review non résolus de mes PR (et de celles que je relis) : ligne `💬` au-dessus
  du prompt, `c` ou `/pr-review` pour les parcourir, les envoyer à Claude, répondre,
  résoudre (plugin `pr-comments`).
- `/pr [numéro | mots-clés]`, `/br [nom | mots-clés]` : trouver une PR ou une branche,
  la charger en contexte et se placer dessus (branche courante ou worktree) ;
  `/worktree clear` supprime les worktrees qu'aucune session n'utilise (plugin `git-nav` ;
  `gpr`, `gbr` dans le terminal).
- `dot` (lié dans `~/.local/bin`) : dérive git, état des liens, `mise upgrade`,
  `herdr update`, `claude update`.
- `./install.sh adopt <fichier>` : versionner un nouveau fichier de `$HOME` (déplacé dans
  `home/`, remplacé par un lien). `./install.sh status` : état de chaque fichier géré.
- `./install.sh capture <fichier>` : repli pour un fichier qu'un outil réécrit en
  remplaçant le lien (recopie `$HOME` → `home/`).

## Structure

```
install.sh          link | setup | status | adopt | capture (défaut : link + setup)
home/               miroir de $HOME, un lien par fichier
  .bash_aliases     charge .config/shell/*.sh (outils shell, voir TOOLS.md)
  .claude/          statusline-*.sh
  .config/          herdr/config.toml, mise/config.toml, shell/{git-tools,claude-profile}.sh
  .local/           bin/{cl,dot}, share/gnome-shell/extensions/claude-notify@ywicker/
.claude-plugin/     marketplace.json : ce dépôt comme marketplace locale « claude-tools »
plugins/            plugins Claude Code : pr-comments/ (repris d'aguiddir/claude-config), intellij/, profiles/ (avec bin/claude-profile),
                    git-nav/ (skills /pr, /br, /worktree, bin/{gpr,gbr}, lib/git-tools.sh),
                    notify/ (hooks et scripts des notifications desktop), herdr-session/ (hook herdr),
                    build-brief/ (consigne et garde-fou Gradle)
profiles/           profils (<nom>.json : settings.json complet de chaque profil — vidal, basic —, voir `claude-profile`)
setup/              scripts idempotents : 10-mise, 20-herdr, 30-gnome, 50-cl, 60-plugins
CLAUDE-CODE.md      Claude Code : settings, profils, plugins
TOOLS.md            outils hors Claude : cl, extension GNOME, herdr, mise
AGENTS.md           consignes pour les agents (CLAUDE.md l'importe)
```
