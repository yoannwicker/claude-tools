# Outils

Une section par outil, même gabarit : rôle · fichiers dans le repo · prérequis ·
installation · fonctionnalités et configuration spécifique.

## Claude Code

**Rôle** : agent de code en terminal ; ce repo porte sa configuration utilisateur
(`~/.claude`), pas la configuration des projets (`.claude/` dans chaque repo).

**Fichiers** : `profiles/*.json` (le `settings.json`, voir [Profils](#profils)), `home/.claude/statusline-command.sh`, `statusline-ps1.sh`,
`notify.sh`, `notify-click.sh`, `claude-notify.py`, `rules/build-brief.md`, `skills/{pr,br}/SKILL.md`, `skills/worktree/{SKILL.md,scan.sh}`, `home/.local/bin/cl` ; plugins :
`.claude-plugin/marketplace.json`, `plugins/{pr-comments,intellij,profiles}/`,
`setup/60-plugins.sh` ; profils : `plugins/profiles/bin/claude-profile` (lié dans `~/.local/bin`),
`profiles/*.json`, `home/.config/shell/claude-profile.sh`.

**Prérequis** : `claude` installé et connecté ; `jq` et `python3` (status line,
notifications) ; `gh` authentifié (skill `/pr`, badge PR de la status line) ; Linux +
GNOME Shell 46 pour les notifications (voir [Notifications desktop](#notifications-desktop)) ;
IntelliJ ouvert avec son serveur MCP pour les outils IDE (voir [MCP IntelliJ](#mcp-intellij)).

**Installation** : `./install.sh link`. Les fichiers d'état et de secrets restent locaux
(`~/.claude.json`, `.credentials.json`, `projects/`, `plugins/`).

### `settings.json`

Pas de `settings.json` versionné dans `home/` : `~/.claude/settings.json` est un lien vers
celui du profil par défaut, généré depuis `profiles/<nom>.json` (voir [Profils](#profils)).
Réglages communs aux profils versionnés (`vidal`, `basic`) :

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

La consigne IntelliJ (ex-`jetbrains-mcp.md`) est portée par le plugin `intellij` avec son
serveur MCP (voir [MCP IntelliJ](#mcp-intellij)).

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

`cl` lance Claude par `claude-profile run`, et `cl -P <profil> [projet] …` par
`claude-profile switch <profil>` : `/profile` peut ensuite relancer la session dans un autre
profil (voir [Profils](#profils)).

### Profils

Un **profil** est un dossier de config généré depuis `~/.claude`, où **seul
`settings.json` diffère**, sur lequel Claude est lancé avec `CLAUDE_CONFIG_DIR`. Le profil
par défaut est celui de `claude` lancé sans profil : `~/.claude/settings.json` est un lien
vers son `settings.json` généré.

- Définition : `profiles/<nom>.json`, un `settings.json` **complet** (plus une clé
  `description`, retirée à la génération) qui devient tel quel celui du profil : rien
  n'est partagé entre profils, une modification commune (un hook, la statusline) est à
  reporter dans chaque profil. `claude-profile new` part d'une copie du profil par défaut.
  Ce qui change d'un profil à l'autre est surtout `enabledPlugins` : les éléments
  activables (MCP, consignes, skills) sont des plugins du marketplace `claude-tools`,
  installés une fois et allumés ou éteints par profil ; `profiles@claude-tools` doit y
  rester activé (sinon pas de `/profile`, `generate` prévient).
- Dossier généré : `~/.claude-profiles/<nom>/` (non versionné) — un lien par entrée de
  `~/.claude` (dossiers liés en entier : historique `projects/`, `plugins/`, rules,
  skills…), `.claude.json` lié à `~/.claude.json`, `settings.json` généré. Session
  connectée, sans onboarding ni confiance redemandée ; `--continue` reprend une
  conversation commencée dans un autre profil.
- Identifiants : `.credentials.json` est un lien, mais Claude Code réécrit ses fichiers
  par renommage, ce qui peut remplacer le lien par un fichier (jetons rafraîchis dans le
  profil). À chaque génération, un tel fichier plus récent que celui de `~/.claude` le
  remplace, puis le lien est reposé.
- Un `settings.json` modifié dans un profil (`/config`, `claude plugin enable`) est
  écrasé à la génération suivante : reporter le changement dans `profiles/<nom>.json`.
- Profil par défaut (`claude-profile default <nom>`, posé à `vidal` par
  `setup/60-plugins.sh` s'il n'y en a pas) : `~/.claude/settings.json` devient un lien vers
  `~/.claude-profiles/<nom>/settings.json` (un fichier ordinaire à sa place est sauvegardé en
  `settings.json.bak.<date>`), donc `claude` lancé sans profil, et `claude-profile current`
  hors `CLAUDE_CONFIG_DIR`, est sur `<nom>`.

Commande `claude-profile` (`plugins/profiles/bin/claude-profile`, `jq` requis) : dans Claude, le `bin/`
du plugin est dans le PATH de l'outil Bash ; pour le terminal, `setup/60-plugins.sh` la
lie dans `~/.local/bin`.

- `claude-profile list` : profils, `*` sur celui de la session, dossier généré ou non,
  `par défaut` sur le profil par défaut ;
- `claude-profile current` : profil de la session (d'après `CLAUDE_CONFIG_DIR`, sinon le
  profil par défaut) ;
- `claude-profile default [<nom>]` : affiche le profil par défaut, ou en fait `<nom>` (il
  est généré) ; les sessions lancées sans profil le prennent à leur prochaine relance ;
- `claude-profile show [<nom>]` : ce qui est actif sur un profil (celui de la session par
  défaut) — plugins activés (`+`) ou non (`-`, ou `?` pour un plugin installé que le profil
  ne mentionne pas), modèle, réglages qui diffèrent du profil par défaut ;
- `claude-profile new <nom> [description…]` : crée `profiles/<nom>.json`, copie du profil
  par défaut (noms réservés : `default`, `show`, `create`) ;
- `claude-profile plugin <nom> <plugin>@<marketplace> on|off` : active ou désactive un plugin
  dans `enabledPlugins` du profil, puis le régénère (le profil par défaut : effet immédiat
  sur `~/.claude/settings.json`) ;
- `claude-profile generate <nom>|--all` : (re)génère le dossier (liens à jour, orphelins
  retirés, `settings.json` recopié du profil) ;
- `claude-profile switch <nom> [arguments claude…]` : régénère puis lance
  `CLAUDE_CONFIG_DIR=~/.claude-profiles/<nom> claude …` (le profil par défaut : `claude`
  sans la variable) ; deux terminaux peuvent tourner sur deux profils ;
- `claude-profile run [arguments claude…]` : lance `claude` sans toucher au profil courant ;
- `claude-profile request <nom> <session>` : demande de bascule, déposée par `/profile`.

Bascule depuis une session : le dossier de config est fixé au lancement, il faut donc un
nouveau processus. `switch` et `run` lancent `claude` dans une boucle et exportent
`CLAUDE_PROFILE_SWITCH_FILE` ; `/profile <nom>` y écrit la demande (`claude-profile request`)
puis quitte la session (`/exit`) ; la boucle régénère `<nom>` et relance
`claude --resume <session>` (session neuve si la session quittée était encore vide), soit
la même conversation dans le nouveau profil. Pour que `claude` tapé à la main passe par
la boucle, `home/.config/shell/claude-profile.sh` (chargé par `~/.bash_aliases`) le
définit comme fonction appelant `claude-profile run` ; `cl` y passe aussi. Lancé autrement
(IDE, lanceur graphique, `command claude`), `/profile` donne la relance manuelle :
`/exit` puis `claude-profile switch <nom> --continue`.

Profils versionnés : `vidal` (config complète : `pr-comments`, `intellij`, `profiles` ;
par défaut à l'installation) et `basic` (le même sans `pr-comments`).

### Plugin `profiles` (`/profile`)

`plugins/profiles/`, activé dans tous les profils :

- commande `/profile` (mod, `hooks/register.tsx`) :
  - sans argument : boîte de dialogue listant les profils (`claude-profile list`, l'actuel
    présélectionné) ; Entrée relance la conversation dans celui choisi, Échap annule ; là
    où elle ne peut s'afficher, la liste en texte ;
  - `<nom>` : vérifie et génère le profil, dépose la demande de bascule puis quitte, la
    boucle de `claude-profile switch`/`run` relançant la conversation dans `<nom>` (voir
    [Profils](#profils)) ; hors boucle, donne la relance manuelle ;
  - `show [<nom>]` : vue d'un profil (`claude-profile show` : plugins, modèle, écarts avec
    le profil par défaut), choisi dans la même liste sans `<nom>`, ouverte en lecture
    seule : `m` passe en édition, `b` bascule dans le profil, Échap ferme. En
    édition, chaque plugin est un bouton `[x]`/`[ ]` qu'Entrée bascule dans un brouillon
    (`*` : modifié) ; `v` valide (`claude-profile plugin` pour chaque changement, profil
    régénéré), `a` annule, Échap ferme sans appliquer. Une modification du profil de la
    session vaut à sa prochaine relance ;
  - `default [<profil>]` : choisit le profil par défaut (`claude-profile default`) dans la
    même liste (le profil par défaut présélectionné) ou celui donné ;
  - `create <nom> [description]` : crée le profil (`claude-profile new`, copie du profil
    par défaut),
    le génère et ouvre sa vue en édition pour choisir ses plugins.

  Logique pure (lecture de `list`/`show`, réponse à une bascule) dans `hooks/switch.ts`,
  testée par `claude plugin test plugins/profiles` ; `types/index.d.ts` déclare l'état du
  mod (brouillon de chaque vue en édition) ;
- `bin/claude-profile` : la commande `claude-profile` (voir [Profils](#profils)).

### Status line

`statusline-command.sh` (bash + Python, lit le JSON de session sur stdin) affiche :
modèle et niveau d'effort, dossier courant, branche git avec compteurs *staged/modifiés*
(détachée → SHA court), PR GitHub ouverte sur la branche via `gh` (cache dans `/tmp`),
nom du worktree, durée de session, et `🧩 <profil>` pour une session lancée sur un profil
(dossier de `CLAUDE_CONFIG_DIR` sous `~/.claude-profiles/`). `statusline-ps1.sh` est la variante minimale
`user@host:~/chemin` (ancien PS1), à brancher dans `statusLine.command` si besoin.

### Skill `/pr`

`/pr [numéro | mots-clés]` : trouve une PR GitHub (`gh pr list`/`view`, PR ouvertes
uniquement ; sans argument, les plus récemment modifiées d'abord) — une seule
correspondance est ouverte directement, plusieurs sont proposées dans un sélecteur (les 4
premières ; les 6 suivantes listées dans la question, à taper dans « Other », plus le
nombre de PR restantes) —, la charge en contexte (description, revue, checks,
commentaires), puis demande toujours où se placer : worktree dédié (recommandé s'il y a
du travail local non commité) ou branche courante. Les outils autorisés sont listés dans le frontmatter du
`SKILL.md`. Toutes les opérations passent par le script `gpr` (sous-commandes `list`,
`view`, `where`, `worktree`, `checkout`, voir [SHELL.md](SHELL.md#gpr--pr-github)).
Prérequis : `gpr` lié dans `~/.local/bin`, `gh` authentifié sur le compte qui voit le repo.

### Skill `/br`

`/br [nom | mots-clés]` : même parcours que `/pr` pour une branche git, locale ou
`origin` (nom exact pris directement, sinon recherche dans le nom et sélecteur ; sans
argument, dernier commit d'abord), la charge en contexte (avance/retard sur la branche
par défaut, commits propres, fichiers, PR liée), puis demande toujours où se placer :
worktree dédié ou branche courante. Toutes les opérations passent par le script `gbr`
(voir [SHELL.md](SHELL.md#gbr--branches-git)). Prérequis : `gbr` lié dans
`~/.local/bin` ; `gh` facultatif (PR liée).

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
ouvertes du dépôt qui ont des fils de review non résolus, en groupes : à traiter
(les tiennes et celle de la branche courante), en relecture (relecture demandée ou déjà
faite) et à relire (relecture demandée, encore aucun fil, sans compteur) —
`💬 à traiter #89 (9) · en relecture #73 (10) · à relire #108`. Une PR à relire passe en
dernier ; son panneau donne le lien GitHub (`o`) et rappelle `/pr <n>` pour s'y placer. `c` dans un prompt vide (tant que
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

Écarts avec l'original : ces raccourcis (l'original : `n`/`p`, `t`, `q` sur QWERTY), la
PR précédente (`q`) et le groupe « à relire », absents de l'original (qui n'affiche que
les PR ayant des fils non résolus).
Réponses et résolutions passent par `gh` sans autre confirmation que la touche.
GitHub est interrogé chaque minute pour la liste (1 point GraphQL sur 5000/h), les fils
d'une PR seulement quand elle a changé, après une écriture, ou toutes les dix minutes.

Installation : `./setup/60-plugins.sh` déclare ce dépôt comme marketplace locale
`claude-tools` (`.claude-plugin/marketplace.json`) et installe `pr-comments@claude-tools`
(activé dans `enabledPlugins` des profils, sauf `basic`). Le plugin est lu directement depuis
`plugins/pr-comments/` : une modification y prend effet au démarrage de session suivant ou
avec `/reload-plugins`. `marketplace add` écrit le chemin absolu du dépôt dans
`extraKnownMarketplaces` de `~/.claude/settings.json` ; le script l'en retire (la
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

Plugin `intellij` (`plugins/intellij/`, activé dans les profils `vidal` et `basic`, à
couper par profil, voir [Profils](#profils)), qui regroupe le serveur MCP et la consigne
d'usage de ses outils :

- `.mcp.json` : serveur `intellij`, transport SSE sur `http://127.0.0.1:64342/sse`
  (plugin MCP Server d'IntelliJ). Outils exposés sous `mcp__plugin_intellij_intellij__*`.
- `instructions.md` : recherche, refactoring et diff via ces outils plutôt que
  `grep`/`find`, sauf MCP injoignable ou projet non ouvert dans l'IDE. Injectée dans le
  contexte par un hook `SessionStart` du plugin (`hooks/hooks.json`, au démarrage, à la
  reprise, après `/clear` et `/compact`) : un plugin ne porte ni `CLAUDE.md` ni rules.

Installation : `./setup/60-plugins.sh`, qui retire aussi l'ancien serveur `intellij` de
scope user (`~/.claude.json`, ex-`setup/40-mcp.sh`) : à même URL, Claude Code garderait
celui-ci et ignorerait celui du plugin. Prérequis : IntelliJ ouvert avec le serveur MCP
actif, sinon `claude mcp list` le montre déconnecté.

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
  `settings.json` avec un **chemin absolu**. Les profils (`profiles/*.json`) portent la variante
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
