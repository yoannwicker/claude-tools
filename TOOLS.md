# Outils

Une section par outil, même gabarit : rôle · fichiers dans le repo · prérequis ·
installation · fonctionnalités et configuration spécifique.

## Claude Code

**Rôle** : agent de code en terminal ; ce repo porte sa configuration utilisateur
(`~/.claude`), pas la configuration des projets (`.claude/` dans chaque repo).

**Fichiers** : `home/.claude/settings.json`, `statusline-command.sh`, `statusline-ps1.sh`,
`notify.sh`, `notify-click.sh`, `claude-notify.py`, `rules/{build-brief,jetbrains-mcp}.md`, `skills/pr/SKILL.md`, `skills/worktree/{SKILL.md,scan.sh}`, `home/.local/bin/cl` ; plugins :
`.claude-plugin/marketplace.json`, `plugins/pr-comments/`, `setup/60-plugins.sh`.

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

### Règles (`~/.claude/rules/`)

Instructions chargées dans toutes les sessions, reprises de `~/.copilot/instructions/`
(noms d'outils adaptés à Claude) :

- `build-brief.md` : toute commande Gradle passe par `build-brief` (`build-brief ./gradlew …`),
  Gradle brut seulement dans les exceptions listées. Prérequis : `build-brief` dans le PATH.
- `jetbrains-mcp.md` : recherche, refactoring et diff via les outils `mcp__intellij__*`
  plutôt que `grep`/`find`, sauf MCP injoignable ou projet non ouvert dans l'IDE
  (voir [MCP IntelliJ](#mcp-intellij)).

### Lanceur `cl`

`cl [projet] [arguments claude…]` : équivalent de `cop` pour Claude. Cherche `projet`
dans les espaces de travail configurés : nom exact, sinon correspondance partielle
insensible à la casse, sinon menu de tous les projets (menu aussi dès que plusieurs
correspondent ; un nom présent dans deux espaces s'affiche `nom (espace)`). Puis `cd` et
`exec claude` avec les arguments restants (`cl babel -c`, `cl vira --resume`). Script et
non fonction shell : le terminal revient dans son dossier d'origine à la sortie.

Espaces de travail : propres à chaque machine, donc dans `~/.config/cl/workspaces` (un
chemin par ligne, non versionné). `setup/50-cl.sh` les fait choisir à l'installation :
il propose les dossiers de `$HOME` qui contiennent des dépôts git (numéros pour cocher,
chemin pour en ajouter un) ; sans terminal (relancé par `./install.sh setup`) il garde la
config existante, sinon retient les `~/workspace*`. Ensuite, en chemin :

- `cl --list` : espaces configurés avec leur nombre de projets (`absent` si disparu) ;
- `cl --add [chemin…]` : ajoute (dossier courant par défaut) ;
- `cl --remove <chemin|numéro>…` : retire (numéros de `--list`) ;
- `cl --setup` : refait la sélection interactive.

`CL_WORKSPACE=dir1:dir2` remplace la config le temps d'une commande ; sans config, repli
sur `~/workspace`.

### Status line

`statusline-command.sh` (bash + Python, lit le JSON de session sur stdin) affiche :
modèle et niveau d'effort, dossier courant, branche git avec compteurs *staged/modifiés*
(détachée → SHA court), PR GitHub ouverte sur la branche via `gh` (cache dans `/tmp`),
nom du worktree, durée de session. `statusline-ps1.sh` est la variante minimale
`user@host:~/chemin` (ancien PS1), à brancher dans `statusLine.command` si besoin.

### Skill `/pr`

`/pr [numéro | mots-clés]` : trouve une PR GitHub (`gh pr list`/`view`, PR ouvertes
uniquement ; sans argument, les plus récemment modifiées d'abord) — une seule
correspondance est ouverte directement, plusieurs sont proposées dans un sélecteur (les 4
premières ; les 6 suivantes listées dans la question, à taper dans « Other », plus le
nombre de PR restantes) —, la charge en contexte (description, revue, checks,
commentaires), puis demande toujours où se placer : worktree dédié (recommandé s'il y a
du travail local non commité) ou branche courante. Les outils autorisés sont listés dans le frontmatter du
`SKILL.md`. Prérequis : `gh` authentifié sur le compte qui voit le repo.

### Skill `/worktree`

`/worktree [list | clear | release]` : liste les worktrees du dépôt courant avec un verdict
(`scan.sh`), et avec `clear` supprime après confirmation ceux qui sont libres. Libre =
ni dépôt principal, ni worktree de la session, ni verrouillé, sans modifications locales,
et sans aucun processus de l'utilisateur dont le cwd est dedans (lecture de
`/proc/*/cwd` : couvre les sessions Claude, les shells et les terminaux IDE). Suppression
par `git worktree remove` sans `--force`, branches conservées, puis `git worktree prune`.

`release` libère le worktree de la session (typiquement une fois la PR terminée, que
`clear` ignore) : refus s'il est verrouillé ou a des modifications non commitées,
confirmation s'il a des commits non poussés ou pas d'upstream ; la session le quitte
(`ExitWorktree` en mode `keep` — `remove` supprimerait aussi la branche — ou `cd` vers
le dépôt principal si elle a été lancée dedans), puis `git worktree remove` depuis le
dépôt principal. La branche est conservée.
Prérequis : Linux (`/proc`).

Prochains skills : un sous-titre par skill, même gabarit (déclencheur, ce qu'il fait,
prérequis).

### Plugin `pr-comments` (fils de review non résolus)

Mod repris de [aguiddir/claude-config](https://github.com/aguiddir/claude-config)
(`plugins/pr-comments`, commit `bac6e75`, licence MIT déclarée dans son `plugin.json`),
copié tel quel dans `plugins/pr-comments/`. Une ligne au-dessus du prompt liste les PR
ouvertes du dépôt qui ont des fils de review non résolus, en deux groupes : à traiter
(les tiennes et celle de la branche courante) et en relecture (relecture demandée ou déjà
faite) — `💬 à traiter #89 (9) · en relecture #73 (10)`. `c` dans un prompt vide (tant que
de nouveaux fils sont arrivés depuis le dernier prompt envoyé), sinon `/pr-review [n]`,
ouvre un panneau qui montre un fil à la fois : le diff concerné et toute la conversation,
avec les badges `↩ répondu` (l'auteur de la PR a le dernier mot) et `obsolète`.

Touches du panneau (adaptées à l'AZERTY, main gauche) : `z`/`s` fil précédent/suivant,
`q`/`d` PR précédente/suivante, `x` marquer, `a` tout (dé)marquer (**a**ll), `f` mettre
les fils marqués (ou celui affiché) dans le prompt pour Claude (**f**ix ; sur ta PR : un
commit `--fixup` par commit corrigé puis push ; sur celle d'un autre : correction locale
sans commit ni push ; si la PR n'est pas sur la branche courante, Claude est prié de s'y
placer d'abord), `r` répondre (**r**etour, publié sur GitHub à Entrée), `v` résoudre le
fil sur GitHub (**v**alider), `o` ouvrir dans le navigateur, `e`/Esc fermer (**e**xit).
La barre d'aide groupe la navigation (`z: ↑ s: ↓ fil · q: ← d: → PR`) au-dessus des
actions. Pas de flèches : un bouton de mod n'accepte qu'une lettre ou un chiffre, et dans
un panneau les flèches font défiler.

Écarts avec l'original : ces raccourcis (l'original : `n`/`p`, `t`, `q` sur QWERTY) et la
PR précédente (`q`), absente de l'original.
Réponses et résolutions passent par `gh` sans autre confirmation que la touche.
GitHub est interrogé chaque minute pour la liste (1 point GraphQL sur 5000/h), les fils
d'une PR seulement quand elle a changé, après une écriture, ou toutes les dix minutes.

Installation : `./setup/60-plugins.sh` déclare ce dépôt comme marketplace locale
`claude-tools` (`.claude-plugin/marketplace.json`) et installe `pr-comments@claude-tools`
(activé dans `settings.json`, `enabledPlugins`). Le plugin est lu directement depuis
`plugins/pr-comments/` : une modification y prend effet au démarrage de session suivant ou
avec `/reload-plugins`. `marketplace add` écrit le chemin absolu du dépôt dans
`extraKnownMarketplaces` du `settings.json` versionné ; le script l'en retire (la
marketplace reste connue via `~/.claude/plugins/known_marketplaces.json`).
Tests : `claude plugin test plugins/pr-comments`.
Prérequis : `gh` authentifié, Claude Code ≥ 2.1.287, `jq` (nettoyage de `settings.json`).

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
