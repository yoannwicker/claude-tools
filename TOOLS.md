# Outils

Une section par outil, même gabarit : rôle · fichiers dans le repo · prérequis ·
installation · fonctionnalités et configuration spécifique.

## Claude Code

**Rôle** : agent de code en terminal ; ce repo porte sa configuration utilisateur
(`~/.claude`), pas la configuration des projets (`.claude/` dans chaque repo).

**Fichiers** : `home/.claude/settings.json`, `statusline-command.sh`, `statusline-ps1.sh`,
`notify.sh`, `notify-click.sh`, `claude-notify.py`, `skills/pr/SKILL.md`.

**Prérequis** : `claude` installé et connecté ; `jq` et `python3` (status line,
notifications) ; `gh` authentifié (skill `/pr`, badge PR de la status line) ; Linux +
GNOME Shell 46 pour les notifications (voir [Notifications desktop](#notifications-desktop)) ;
IntelliJ ouvert avec son serveur MCP pour les outils IDE (voir [MCP IntelliJ](#mcp-intellij)).

**Installation** : `./install.sh link`. Les fichiers d'état et de secrets restent locaux
(`~/.claude.json`, `.credentials.json`, `projects/`, `plugins/`).

### `settings.json`

- Modèle par défaut `opus` ; niveaux d'effort par modèle (`modelSettings` : `high` pour
  `claude-fable-5-1`, `medium` pour `claude-opus-5-5`) ; thème `dark`.
- `worktree.baseRef = "fresh"` : les worktrees créés par Claude partent d'une base fraîche.
- Hooks : `Stop`, `StopFailure`, `Notification` → `notify.sh` (notification desktop) ;
  `UserPromptSubmit` → `notify.sh` (efface les notifications en attente de la session) ;
  `SessionStart` → intégration herdr, gardée par `[ -f … ]` pour être sans effet sur une
  machine sans herdr (voir [herdr](#herdr)).
- `statusLine` → `statusline-command.sh`, rafraîchie toutes les 10 s.
- `autoContinueAtUsageLimit = false`, `inputNeededNotifEnabled = true`.

### Status line

`statusline-command.sh` (bash + Python, lit le JSON de session sur stdin) affiche :
modèle et niveau d'effort, dossier courant, branche git avec compteurs *staged/modifiés*
(détachée → SHA court), PR GitHub ouverte sur la branche via `gh` (cache dans `/tmp`),
nom du worktree, durée de session. `statusline-ps1.sh` est la variante minimale
`user@host:~/chemin` (ancien PS1), à brancher dans `statusLine.command` si besoin.

### Skill `/pr`

`/pr <numéro | mots-clés>` : trouve une PR GitHub (`gh pr list`/`view`, PR ouvertes
uniquement), la charge en contexte (description, revue, checks, commentaires), puis
demande toujours où se placer : worktree dédié (recommandé s'il y a du travail local non
commité) ou branche courante. Les outils autorisés sont listés dans le frontmatter du
`SKILL.md`. Prérequis : `gh` authentifié sur le compte qui voit le repo.

Prochains skills : un sous-titre par skill, même gabarit (déclencheur, ce qu'il fait,
prérequis).

### Notifications desktop

Chaîne : hook Claude → `notify.sh` (lit le JSON de l'événement, construit titre/corps,
détache le reste pour rendre la main tout de suite) → `claude-notify.py` (libnotify via
`gi`, affiche, mémorise la notification comme *en attente* dans
`~/.local/state/claude-notify/`, suit le clic) → `notify-click.sh` (`--open` ramène
l'onglet gnome-terminal de la session au premier plan via `gdbus`, `--clear-session` /
`--clear-all` ferment les notifications en attente). L'extension GNOME ci-dessous
consomme le même état.

Prérequis : GNOME Shell + gnome-terminal, `python3-gi` avec `Notify 0.7`, `gdbus`,
`xprop`, `jq`. `setup/30-gnome.sh` signale ce qui manque.

### MCP IntelliJ

Serveur MCP utilisateur `intellij`, transport SSE sur `http://127.0.0.1:64342/sse`
(plugin MCP Server d'IntelliJ). Il vit dans `~/.claude.json` (non versionné) ; `setup/40-mcp.sh`
le déclare s'il manque (`claude mcp add --scope user --transport sse …`). Prérequis :
IntelliJ ouvert avec le serveur MCP actif, sinon `claude mcp list` le montre déconnecté.

## Extension GNOME `claude-notify@ywicker`

**Rôle** : pastille dans le panneau GNOME avec le nombre de notifications Claude Code en
attente ; menu pour revenir sur une session ou tout effacer.

**Fichiers** : `home/.local/share/gnome-shell/extensions/claude-notify@ywicker/`
(`extension.js`, `metadata.json`, `stylesheet.css`).

**Prérequis** : GNOME Shell 46 (`shell-version` dans `metadata.json`), les scripts de
notification ci-dessus (l'extension appelle `~/.claude/notify-click.sh`).

**Installation** : `./install.sh link` puis `./setup/30-gnome.sh`
(`gnome-extensions enable claude-notify@ywicker`). Après un premier lien, GNOME Shell ne
voit l'extension qu'au prochain login : se déconnecter/reconnecter puis relancer le script.

## herdr

**Rôle** : gestionnaire de workspaces terminal pour agents IA (panes, onglets, état des
agents, worktrees).

**Fichiers** : `home/.config/herdr/config.toml`, seul fichier de configuration. Restent
locaux dans `~/.config/herdr/` : `*.log`, `*.sock`, `session.json`, `release-notes.json`,
`.plugins.lock`. Le binaire (`~/.local/bin/herdr`) n'est pas versionné.

**Prérequis** : Linux ou macOS, `curl`.

**Installation** : `./setup/20-herdr.sh`, soit
`curl -fsSL https://herdr.dev/install.sh | sh`, puis `herdr integration install claude`
(et `copilot` si la CLI Copilot est présente). Mise à jour : `herdr update` (fait par `dot`).

**Configuration spécifique** :
- `onboarding = false` ; `[update] channel = "stable"`. Toute section ajoutée ensuite
  (`[keys]`, `[theme]`, `[ui]`, `[terminal]`) se documente ici.
- Intégration Claude : herdr génère `~/.claude/hooks/herdr-agent-state.sh` (fichier
  « managed by herdr », non versionné) et ajoute un hook `SessionStart` dans
  `settings.json` avec un **chemin absolu**. Le `settings.json` versionné porte la variante
  portable `[ -f "$HOME/.claude/hooks/herdr-agent-state.sh" ] && bash … session || true` ;
  comme herdr ne la reconnaît pas, chaque `integration install` ajoute un doublon absolu,
  que `setup/20-herdr.sh` retire (en écrivant à travers le lien). `dot` rejoue ce script
  après `herdr update`.
- Vérifier : `herdr integration status` → `claude: current`.

## mise

**Rôle** : installation d'outils en espace utilisateur (pas de sudo sur la machine pro).

**Fichiers** : `home/.config/mise/config.toml` — outils globaux : `jq`.

**Installation** : `./setup/10-mise.sh` (`curl https://mise.run | sh` si absent, puis
`mise install`). L'activation shell (`eval "$(mise activate bash)"`) reste dans le
`.bashrc`, hors repo pour l'instant. Les versions `node`/`java` des projets sont dans le
`mise.toml` de chaque repo, pas ici.

## Gabarit pour un nouvel outil

```
## <outil>
**Rôle** : …
**Fichiers** : home/… (ce qui reste local : …)
**Prérequis** : …
**Installation** : ./setup/NN-<outil>.sh — commandes
**Configuration spécifique** : …
```
