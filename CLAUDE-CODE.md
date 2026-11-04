# Claude Code

Configuration utilisateur de Claude Code et ses plugins. Les outils hors Claude (lanceur
`cl`, extension GNOME, herdr, mise) sont dans [TOOLS.md](TOOLS.md).

**Rôle** : agent de code en terminal ; ce repo porte sa configuration utilisateur
(`~/.claude`), pas la configuration des projets (`.claude/` dans chaque repo).

**Fichiers** : `home/.claude/settings.json` (le profil de référence), `profiles/*.json` (surcharges, voir [Profils](#profils)), `home/.claude/statusline-command.sh`, `statusline-ps1.sh` ;
plugins : `.claude-plugin/marketplace.json`,
`plugins/{pr-comments,intellij,profiles,git-nav,git-tidy,notify,herdr-session,build-brief,session-analysis,review}/` (avec
leur `setup.sh`), `install.sh plugin` (voir [Installation des plugins](#installation-des-plugins)).

**Prérequis** : `claude` installé et connecté ; `jq` et `python3` (status line) ; `gh`
authentifié (plugins [`git-nav`](#git-nav), [`git-tidy`](#git-tidy) et [`review`](#review), badge PR de la status line) ; Linux + GNOME pour
les notifications (plugin [`notify`](#notify)) ;
IntelliJ ouvert avec son serveur MCP pour les outils IDE (voir [`intellij`](#intellij)) ;
`build-brief` dans le PATH pour Gradle (plugin [`build-brief`](#build-brief)) ;
AgentsView pour l'analyse des sessions (plugin [`session-analysis`](#session-analysis), qui
l'installe).

**Installation** : `./install.sh link`, puis `./install.sh plugin <nom>…` ou
`./install.sh plugin --all` pour les plugins (voir [Installation des plugins](#installation-des-plugins)). Les fichiers d'état et de secrets restent locaux
(`~/.claude.json`, `.credentials.json`, `projects/`, `plugins/`).

## `settings.json`

`home/.claude/settings.json`, lié à `~/.claude/settings.json`, est le **profil de référence** : le
`settings.json` complet, celui de `~/.claude` sans profil, dont les profils
reprennent tout sauf ce qu'ils surchargent (voir [Profils](#profils)). Un changement fait
hors profil (`/config`, `claude plugin enable`) l'écrit donc dans le dépôt. Réglages :

- Modèle par défaut `opus` ; niveaux d'effort par modèle (`modelSettings` : `high` pour
  `claude-fable-5-1`, `medium` pour `claude-opus-5-5`) ; thème `dark`.
- `worktree.baseRef = "fresh"` : les worktrees créés par Claude partent d'une base fraîche.
- Aucun hook : ils viennent des plugins ([`notify`](#notify),
  [`herdr-session`](#herdr-session), [`intellij`](#intellij)).
- `statusLine` → `statusline-command.sh`, rafraîchie toutes les 10 s.
- `autoContinueAtUsageLimit = false`, `inputNeededNotifEnabled = true`.
- Notifications desktop : plugin [`notify`](#notify), activé dans `enabledPlugins`.

## Profils

Un **profil** est une **surcharge** du profil de référence, versionnée dans `profiles/<nom>.json` :
`{ "description": …, "enabledPlugins": { … } }`, plus au besoin `deniedMcpServers` et
`disableClaudeAiConnectors` (MCP coupés). Son `settings.json` est le profil de référence dont
chacune de ces sections est **remplacée en entier** par celle du profil ; toute autre clé est
refusée. Le bouton de `/mcp` (`disabledMcpServers`, dans `.claude.json` commun à tous les
profils) ne distingue pas les profils : couper un MCP par profil passe par
`claude-profile mcp` ou `/profile show`. Une modification commune (un
réglage, la statusline) se fait donc une fois, dans le profil de référence.

Profils versionnés : `vidal` (config complète : tous les plugins du dépôt sauf `pr-comments`,
plus `superpowers`, à installer une fois dans Claude Code :
`/plugin install superpowers@claude-plugins-official`) et `lean` (le même sans
`superpowers` ni [`review`](#review), mais seuls les MCP `claude.ai Atlassian MCP` et
`plugin:intellij:intellij` restent allumés, les autres connecteurs claude.ai étant coupés par
url dans `deniedMcpServers`). Aucun profil par défaut à l'installation : `claude` part sur le
profil de référence (tous les plugins du dépôt sauf `pr-comments`).

Passer d'un profil à l'autre demande le plugin [`profiles`](#profiles) (`/profile`,
`claude-profile`).

## Status line

`statusline-command.sh` (bash + Python, lit le JSON de session sur stdin) affiche :
modèle et niveau d'effort, dossier courant, branche git avec compteurs *staged/modifiés*
(détachée → SHA court), PR GitHub ouverte sur la branche via `gh` (cache dans `/tmp`),
nom du worktree, durée de session, et `🧩 <profil>` pour une session lancée sur un profil
(dossier de `CLAUDE_CONFIG_DIR` sous `~/.claude-profiles/`). `statusline-ps1.sh` est la variante minimale
`user@host:~/chemin` (ancien PS1), à brancher dans `statusLine.command` si besoin.

## Notifications desktop

Portées par le plugin [`notify`](#notify).

## Skills

Les skills `/pr`, `/br`, `/worktree` (et `branch-cleanup`, lancé par Claude après un merge) sont dans le plugin [`git-nav`](#git-nav), `/git-tidy:commits`, `:pr-sync` et `:ready` dans [`git-tidy`](#git-tidy), `/session-analysis:report` et `:session` dans [`session-analysis`](#session-analysis), `/review:diff`, `:pr`, `:feedback`, `:pr-auto` et `:feedback-auto` dans [`review`](#review). Un skill
qui n'a pas sa place dans un plugin va dans `home/.claude/skills/` (relié par
`./install.sh link`).

## Plugins

Les éléments activables (MCP, consignes, mods, skills de plugin) sont des plugins de la
marketplace locale `claude-tools` : ce dépôt, déclaré par `.claude-plugin/marketplace.json`.
Une consigne passe par un plugin (hook `SessionStart`, voir [`intellij`](#intellij),
[`build-brief`](#build-brief)) plutôt que par `~/.claude/rules/`, chargé dans tous les
profils sans moyen de l'éteindre.
Ils sont installés une fois et allumés ou éteints dans `enabledPlugins` du `settings.json`,
donc par profil (voir [Profils](#profils) ; `/profile show` du plugin
[`profiles`](#profiles) pour les (dés)activer).

Un plugin est lu directement depuis `plugins/<plugin>/` : une modification y prend effet
au démarrage de session suivant ou avec `/reload-plugins`. Tests :
`claude plugin test plugins/<plugin>`.

Même gabarit pour chaque plugin : **Rôle**, **Fichiers** et **Activé dans** (profils),
**Prérequis**, l'installation hors de ce dépôt s'il s'utilise seul, puis le fonctionnement.

### Installation des plugins

Un plugin à la fois, avec ce qu'il pose hors de lui :

```
./install.sh plugin <nom>…           installe, ou met à jour s'il l'est déjà
./install.sh plugin --all            tous ceux de marketplace.json (ce que fait ./install.sh)
./install.sh plugin --remove <nom>…  désinstalle (--remove --all : tous)
./install.sh plugin                  état des plugins (aussi dans ./install.sh status)
```

`--all` et `./install.sh` ne font qu'appeler l'installation de chaque plugin l'une après
l'autre : pas d'étape globale en plus. Il n'y a besoin ni de `./install.sh link` ni de
`setup/` pour installer un plugin seul. Prérequis : `claude` ≥ 2.1.287, `jq`.

Déroulé d'un appel :

1. Ménage : les liens morts vers le dépôt (restes d'anciennes installations : fichier
   déplacé de `home/` dans un plugin, lien `~/.claude/rules/…`, `~/.claude/skills/…`) sont
   retirés de `~/.claude`, `~/.claude-profiles/*`, `~/.config/shell` et `~/.local/bin`,
   ainsi que le dossier de `~/.claude` qui les contenait s'il en reste vide. Seuls ces
   liens sont visés, jamais un fichier ordinaire ni un lien vers ailleurs
   (`./install.sh link` fait le même ménage).
2. Marketplace `claude-tools` déclarée (`claude plugin marketplace add`, sinon `update`).
3. Pour chaque plugin : `claude plugin install <p>@claude-tools`, ou `update` s'il est
   installé ; puis les liens déclarés dans son `setup.sh` (un fichier ordinaire différent
   déjà en place est sauvegardé en `*.bak.<date>`) ; puis son `on_install`. Au retrait :
   `on_remove`, liens retirés s'ils pointent bien vers le plugin (sinon laissés et
   signalés), `claude plugin uninstall`, et la liste des profils (référence comprise) qui
   l'activent encore, avec la commande pour l'y éteindre.
4. Profil de référence remis tel qu'il était : `claude plugin` écrit dans
   `~/.claude/settings.json`, donc dans `home/.claude/settings.json` versionné
   (`extraKnownMarketplaces`, `model`, entrée `enabledPlugins` retirée par `uninstall`).
   Seule exception : un plugin installé qui n'a aucune entrée dans `enabledPlugins` y est
   mis à `true`. Activer ou éteindre un plugin dans un profil reste à
   [`/profile show`](#profile) et `claude-profile plugin`.
5. Si `profiles` est installé : `claude-profile generate --all`.

`./install.sh status` (et `./install.sh plugin` sans argument) donne pour chaque plugin de
`marketplace.json` : `absent` (pas une erreur, installation à la carte), `ok` ou `UPDATE`
(un commit a touché `plugins/<p>/` depuis la version installée, le SHA du dépôt à
l'install/update), puis l'état de ses liens (`ok`, `MISSING`, `WRONG`, `DIFF`) et ce que
signale son `on_status` (`note` : avertissement ; échec : erreur). Les liens morts vers le
dépôt sortent en `ORPHAN`. Code retour 1 si quelque chose cloche.

#### `setup.sh` d'un plugin

Ce qu'un plugin pose ou vérifie hors de lui est déclaré dans `plugins/<p>/setup.sh`,
fichier facultatif sourcé par `install.sh` (Claude Code l'ignore) :

```bash
links=(                                  # <chemin dans le plugin>  <destination>
  "bin/gpr              ~/.local/bin/gpr"
  "shell/git-tools.sh   ~/.config/shell/git-tools.sh"
)
on_install() { …; }   # facultatifs et idempotents ; ils voient $repo, $plugin_dir
on_remove()  { …; }   # et note "<message>" (avertissement affiché par status)
on_status()  { …; }   # retour non nul = erreur
```

Les liens suffisent au cas courant : pose, contrôle et retrait sont faits par
`install.sh`. Les hooks ne servent qu'à ce qui ne se ramène pas à un lien (MCP à retirer,
outil à vérifier). Pas de `setup.sh` : le plugin n'a rien hors de lui (`pr-comments`).

### `pr-comments`

**Rôle** : fils de review non résolus des PR du dépôt, au-dessus du prompt et dans un panneau.

**Fichiers** : `plugins/pr-comments/`. **Activé dans** : aucun profil versionné (à allumer par `/profile show` ou `claude-profile plugin`).

**Prérequis** : `gh` authentifié, Claude Code ≥ 2.1.287. Tests : `claude plugin test plugins/pr-comments`.

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
Pour faire analyser tous les fils d'une de tes PR et proposer une suite à chacun :
`/review:feedback` (plugin [`review`](#review)).
GitHub est interrogé chaque minute pour la liste (1 point GraphQL sur 5000/h), les fils
d'une PR seulement quand elle a changé, après une écriture, ou toutes les dix minutes.

### `intellij`

**Rôle** : serveur MCP IntelliJ et consigne d'usage de ses outils, ensemble.

**Fichiers** : `plugins/intellij/`. **Activé dans** : tous les profils.

**Prérequis** : IntelliJ ouvert avec le serveur MCP actif, sinon `claude mcp list` le montre
déconnecté.

- `.mcp.json` : serveur `intellij`, transport SSE sur `http://127.0.0.1:64342/sse`
  (plugin MCP Server d'IntelliJ). Outils exposés sous `mcp__plugin_intellij_intellij__*`.
- `instructions.md` : ces outils sont obligatoires au lieu de `grep`/`find` pour la
  recherche, le refactoring et le diff, sauf MCP injoignable, projet non ouvert dans l'IDE
  ou agent sans outils `mcp__plugin_intellij_*` ; un outil cité par une skill projet y est lu comme une
  intention, pas une obligation. Injectée dans le contexte par un hook `SessionStart` du
  plugin (`hooks/hooks.json`, au démarrage, à la reprise, après `/clear` et `/compact`) :
  un plugin ne porte ni `CLAUDE.md` ni rules.

Couper seulement le serveur dans un profil (`plugin:intellij:intellij`, voir
[`claude-profile mcp`](#claude-profile)) laisse la consigne injectée, qui citerait des outils
absents : mieux vaut éteindre le plugin entier.

`setup.sh` : `on_install` retire l'ancien serveur `intellij` de scope user
(`~/.claude.json`, ex-`setup/40-mcp.sh`) — à même URL, Claude Code garderait celui-ci et
ignorerait celui du plugin — et `on_status` le signale en erreur s'il est encore là.

### `profiles`

**Rôle** : lancer Claude sur un profil et en changer en cours de session — commande
`claude-profile` et commande `/profile`.

**Fichiers** : `plugins/profiles/` (`bin/claude-profile`, mod `/profile` dans `hooks/`,
`shell/claude-profile.sh`, `setup.sh`) ; hors du plugin, les liens
`~/.local/bin/claude-profile` et `~/.config/shell/claude-profile.sh` posés par
`./install.sh plugin profiles`. **Activé dans** : tous les profils
(`profiles@claude-tools` doit y rester activé, sinon pas de `/profile` ; `generate` prévient).

**Prérequis** : `jq`. Tests : `claude plugin test plugins/profiles`.

#### Installation hors de ce dépôt

Pour utiliser le plugin seul, sans le reste de la config. `claude-profile` cherche les
profils dans `profiles/` du dépôt d'où il est lancé : passer par un clone (marketplace
locale), pas par `claude plugin marketplace add yoannwicker/claude-tools`. Le profil de référence est
son propre `~/.claude/settings.json`, tel quel.

```bash
git clone https://github.com/yoannwicker/claude-tools.git ~/claude-tools
~/claude-tools/install.sh plugin profiles   # marketplace locale, plugin, claude-profile et claude-profile.sh liés

# Premier profil : les plugins du profil de référence (~/.claude/settings.json), à adapter
claude-profile new perso "ma config"
```

Les profils `vidal` et `lean` du dépôt sont ceux de l'auteur : à supprimer ou garder comme
exemples. Ensuite, `/profile show <nom>` pour choisir ses plugins, et au besoin
`claude-profile default <nom>`. Pour que `claude` tapé à la main permette
`/profile <nom>` sans relance manuelle, charger
`~/.config/shell/claude-profile.sh` (lien posé ci-dessus) depuis `~/.bashrc` (voir
[Bascule depuis une session](#bascule-depuis-une-session)).

#### Dossiers de profil

Chaque profil est généré en un dossier de config, `~/.claude-profiles/<nom>/` (non
versionné), copie de `~/.claude` où **seul `settings.json` diffère**, sur lequel Claude est
lancé avec `CLAUDE_CONFIG_DIR`. Le profil de référence n'a pas de dossier : c'est `~/.claude`, sans la
variable (nom réservé `reference`).

- Contenu : un lien par entrée de `~/.claude` (dossiers liés en entier : historique
  `projects/`, `plugins/`, rules, skills…), `.claude.json` lié à `~/.claude.json`,
  `settings.json` généré : le profil de référence (`~/.claude/settings.json`) avec les
  sections de `profiles/<nom>.json` (`enabledPlugins`, et `deniedMcpServers`,
  `disableClaudeAiConnectors` s'il les porte). Régénéré à chaque lancement par `switch`/`run`, il reprend
  donc une modification du profil de référence à la session suivante. Session
  connectée, sans onboarding ni confiance redemandée ; `--continue` reprend une
  conversation commencée dans un autre profil.
- Identifiants : `.credentials.json` est un lien, mais Claude Code réécrit ses fichiers
  par renommage, ce qui peut remplacer le lien par un fichier (jetons rafraîchis dans le
  profil). À chaque génération, un tel fichier plus récent que celui de `~/.claude` le
  remplace, puis le lien est reposé.
- Un `settings.json` modifié dans un profil (`/config`, `claude plugin enable`) est
  écrasé à la génération suivante : reporter le changement dans le profil de référence, ou dans
  `profiles/<nom>.json` pour les plugins.
- Profil par défaut, facultatif (`claude-profile default <nom>`) : nommé dans
  `~/.claude-profiles/.default`, c'est celui des nouvelles sessions lancées par
  `claude-profile run` (fonction shell `claude`, `cl`) ; une reprise par `run`
  (`--continue`, `--resume`) part elle sur le dernier profil de la conversation ; sans lui, elles partent sur le
  profil de référence.
- Profil d'un projet, facultatif (`claude-profile project <nom>`, depuis le projet) : nommé
  dans `.claude/profile.local` à la racine du projet (dépôt git, sinon dossier courant), il
  passe avant le profil par défaut pour les nouvelles sessions de `run` lancées dans le
  projet (ou un de ses sous-dossiers ; les autres worktrees du dépôt reprennent celui du
  worktree principal). Non versionné : la commande génère `.claude/.gitignore` (qui ignore
  `profile.local` et s'ignore lui-même), ou complète celui du projet s'il existe. Un nom de
  profil qui n'existe plus est signalé et ignoré. `~/.claude/settings.json` reste le lien vers le profil de référence : une session
  lancée sans passer par `run` (IDE, lanceur graphique, `command claude`, herdr) part sur
  le profil de référence ; `/profile <nom>` reste possible, avec relance manuelle.
- Migration depuis l'ancien modèle (profils complets, `~/.claude/settings.json` lien vers
  un profil généré) : `./install.sh link` relie `~/.claude/settings.json` au profil de référence ;
  tant que ce n'est pas fait, `generate` le signale.

#### `claude-profile`

Dans Claude, le `bin/` du plugin est dans le PATH de l'outil Bash ; pour le terminal,
`./install.sh plugin profiles` la lie dans `~/.local/bin`.

- `claude-profile list` : `reference` en tête, puis les profils ; `*` sur celui de la
  session, dossier généré ou non, `par défaut` sur le profil par défaut (le profil de référence s'il
  n'y en a pas), `projet` sur celui du projet courant ;
- `claude-profile current` : profil de la session (d'après `CLAUDE_CONFIG_DIR`, sinon
  `reference`) ;
- `claude-profile default [<nom>|--unset]` : affiche le profil par défaut (`reference` s'il
  n'y en a pas), ou en fait `<nom>` (il est généré) ; `reference` ou `--unset` le retire ;
  vaut pour les nouvelles sessions de `run` ;
- `claude-profile project [<nom>|--unset]` : affiche le profil du projet courant (avec son
  fichier), ou en fait `<nom>` (il est généré ; `.claude/profile.local` et son
  `.gitignore` écrits à la racine du projet) ; `--unset` retire le fichier (et le
  `.gitignore` s'il est resté tel que généré) ; refusé dans `$HOME` ;
- `claude-profile show [<nom>]` : ce qui est actif sur un profil (celui de la session par
  défaut) — plugins activés (`+`) ou non (`-`, ou `?` pour un plugin installé que le profil
  ne mentionne pas), avec `(référence : activé|désactivé)` quand la référence diffère ;
  MCP actifs (`+`) ou coupés (`-`), en tête `claude.ai` pour tous les connecteurs, avec
  `(référence : …)` quand la référence diffère (serveurs : cache de `mcp-scan`, plus ceux
  des `.mcp.json` des plugins activés) ; modèle, et la liste des plugins différents du
  profil de référence ;
- `claude-profile new <nom> [description…]` : crée `profiles/<nom>.json` avec les plugins
  du profil de référence (noms réservés : `reference`, `default`, `project`, `show`, `create`,
  `stop`, `cancel`) ;
- `claude-profile plugin <nom> <plugin>@<marketplace> on|off` : active ou désactive un plugin
  dans `enabledPlugins` du profil, puis le régénère ; `reference` l'écrit dans
  `~/.claude/settings.json`, à travers le lien (donc dans le dépôt) ;
- `claude-profile mcp <nom> <serveur|url|claude.ai> on|off` : coupe ou réactive un MCP
  dans le profil, puis le régénère ; vaut à la session suivante. Un nom donne une entrée
  `{serverName}` de `deniedMcpServers`, une url (`http(s)://…`, jokers `*` admis) une entrée
  `{serverUrl}`, `claude.ai` bascule `disableClaudeAiConnectors` (tous les connecteurs).
  Noms : ceux de `claude mcp list`, soit `plugin:<plugin>:<serveur>` pour un MCP de plugin
  (le nom seul du `.mcp.json` ne marche pas) et `claude.ai <Nom>` pour un connecteur (nom
  affiché, susceptible de changer : une url est plus robuste). `on` retire aussi les
  entrées `serverUrl` qui couvrent l'url connue du serveur. Un profil sans sa propre liste
  part de celle de la référence (section remplacée en entier) ;
- `claude-profile mcp-scan` : relève les MCP connus avec `claude mcp list` sur le profil de
  référence (~6 s : il contacte chaque serveur), fusionnés dans le cache
  `~/.claude-profiles/.mcp-servers.json` (un serveur coupé par la référence y reste) ; fait
  automatiquement par `show` si le cache manque, à relancer après l'ajout d'un connecteur.
  Ce cache est commun à tous les profils et n'est pas surchargeable (ce n'est pas un
  réglage, seulement la liste proposée par `show`) ; chaque relevé refait toutes les
  connexions, sans relevé incrémental ni par profil : pas utile pour l'instant, à ajouter
  plus tard si besoin ;
- `claude-profile check <nom>` : vérifie un profil (objet JSON, seulement des clés
  surchargeables) ;
- `claude-profile generate <nom>|--all` : (re)génère le dossier (liens à jour, orphelins
  retirés, `settings.json` refait depuis le profil de référence et le profil) ;
- `claude-profile switch <nom> [arguments claude…]` : régénère puis lance
  `CLAUDE_CONFIG_DIR=~/.claude-profiles/<nom> claude …` (`reference` : `claude` sans la
  variable) ; deux terminaux peuvent tourner sur deux profils ;
- `claude-profile run [arguments claude…]` : lance `claude` sur le profil du projet courant,
  sinon le profil par défaut, sinon le profil de référence, ou sans toucher au profil courant dans une session de profil ;
  une reprise (`--resume <id>`, ou `--continue` : la conversation la plus récente du
  dossier) part sur le dernier profil de la conversation, s'il est connu et existe encore ;
- `claude-profile remember <session>` : retient le profil courant pour la session, dans
  `~/.claude-profiles/.sessions` (1000 dernières) ; appelé par le plugin au démarrage de
  chaque session, dont les relances d'une bascule ;
- `claude-profile request <nom> <session>|--cancel` : demande de bascule, déposée (ou retirée)
  par `/profile` ; `claude-profile background` : code 0 dans une session d'arrière-plan.

#### Bascule depuis une session

Le dossier de config est fixé au lancement, il faut donc un nouveau processus. `switch` et
`run` lancent `claude` dans une boucle et exportent `CLAUDE_PROFILE_SWITCH_FILE` ;
`/profile <nom>` y écrit la demande (`claude-profile request`) puis quitte la session
(`/exit`) ; la boucle régénère `<nom>` et relance `claude --resume <session>` (session
neuve si la session quittée était encore vide), soit la même conversation dans le nouveau
profil. Pour que `claude` tapé à la main passe par la boucle,
`shell/claude-profile.sh` du plugin (lié dans `~/.config/shell/`, chargé par `~/.bash_aliases`) le définit comme
fonction appelant `claude-profile run` ; `cl` y passe aussi. Lancé autrement (IDE, lanceur
graphique, `command claude`), `/profile` donne la relance manuelle : `/exit` puis
`claude-profile switch <nom> --continue`. Une session passée en arrière-plan (sous
`claude daemon`, reconnue à `CLAUDE_JOB_DIR`, variable non documentée) ne se quitte pas par
`/exit`, qui la détache seulement : le `claude` que la boucle attend continue. `/profile <nom>`
y dépose la demande et l'indique : `/profile stop` arrête la session (`claude stop`), et la
boucle la relance dans `<nom>` une fois le `claude` du terminal quitté (Ctrl+C) ;
`/profile cancel` annule la demande (`claude-profile request --cancel`), qui sinon
s'appliquerait à la fermeture de ce `claude`. Une session d'arrière-plan ne peut pas être
relancée en arrière-plan dans un autre profil : le daemon les démarre toutes avec son propre
environnement, donc son `CLAUDE_CONFIG_DIR`.

#### `/profile`

Mod (`hooks/register.tsx`) :

- sans argument : boîte de dialogue listant les profils (`claude-profile list`, l'actuel
  présélectionné) ; Entrée relance la conversation dans celui choisi, Échap annule ; là
  où elle ne peut s'afficher, la liste en texte ;
- `<nom>` : vérifie et génère le profil, dépose la demande de bascule puis quitte (voir
  [Bascule depuis une session](#bascule-depuis-une-session)) ; hors boucle, donne la
  relance manuelle ;
- `<nom>` vaut aussi `reference`, pour revenir au profil de référence ;
- `show [<nom>]` : vue d'un profil (`claude-profile show` : plugins, modèle, écarts avec
  le profil de référence), choisi dans la même liste sans `<nom>`, ouverte en lecture
  seule : `m` passe en édition, `b` bascule dans le profil, Échap ferme. En
  édition, chaque plugin et chaque MCP est un bouton `[x]`/`[ ]` qu'Entrée bascule dans
  un brouillon (`*` : modifié) ; `v` valide (`claude-profile plugin` ou `mcp` pour chaque
  changement, profil régénéré), `a` annule, Échap ferme sans appliquer. Une modification du profil de la
  session vaut à sa prochaine relance ;
- `default [<profil>]` : choisit le profil par défaut (`claude-profile default`) dans la
  même liste (le profil par défaut présélectionné ; `reference` pour n'en garder aucun) ou
  celui donné ;
- `project [<profil>|--unset]` : choisit le profil du projet de la session
  (`claude-profile project`, lancé dans son dossier) dans la même liste (celui du projet
  présélectionné) ou celui donné ; `--unset` le retire ;
- `create <nom> [description]` : crée le profil (`claude-profile new`, plugins du
  profil de référence), le génère et ouvre sa vue en édition pour choisir ses plugins ;
- `stop` / `cancel` : dans une session d'arrière-plan, l'arrêter pour que la bascule
  demandée se fasse, ou annuler cette demande (voir
  [Bascule depuis une session](#bascule-depuis-une-session)).

Logique pure (lecture de `list`/`show`, réponse à une bascule) dans `hooks/switch.ts`,
testée par `claude plugin test plugins/profiles` ; `types/index.d.ts` déclare l'état du
mod (brouillon de chaque vue en édition).

### `git-nav`

**Rôle** : naviguer entre PR, branches et worktrees git — skills `/pr`, `/br`,
`/worktree` et leurs scripts `gpr`, `gbr` (aussi pour le terminal, voir
[`gpr`, `gbr` dans le terminal](#gpr-gbr-dans-le-terminal)) — et faire le ménage d'une
branche après son merge ([ménage après un merge](#ménage-après-un-merge)).

**Fichiers** : `plugins/git-nav/` (`skills/{pr,br,worktree,branch-cleanup}/SKILL.md`,
`bin/{gpr,gbr,worktree-scan}`, `lib/git-tools.sh`, `shell/git-tools.sh`,
`hooks/{hooks.json,merge-watch.py}`, `tests/{merge-watch,gbr-cleanup}.test.sh`, `setup.sh`) ; hors
du plugin, les liens `~/.local/bin/{gpr,gbr}` et `~/.config/shell/git-tools.sh` (fonctions
shell `gpr`/`gbr`, alias) posés par `./install.sh plugin git-nav`. **Activé dans** : tous
les profils.

**Prérequis** : `git` ; `gh` authentifié (`/pr`, ménage après un merge, facultatif pour
`/br`) ; Linux pour `/worktree` et le ménage après un merge (`/proc`) ; `python3` (hook).
Tests : `bash plugins/git-nav/tests/merge-watch.test.sh` et
`bash plugins/git-nav/tests/gbr-cleanup.test.sh` (hook commande et script, pas un mod :
`claude plugin test` ne s'applique pas).

`bin/` du plugin est dans le PATH de l'outil Bash : les skills appellent `gpr`, `gbr`,
`worktree-scan` par leur nom, et leurs `allowed-tools` (`Bash(gpr:*)`…) ne dépendent
d'aucun chemin. `gpr` et `gbr` chargent `lib/git-tools.sh` par un chemin relatif à leur
emplacement réel (`readlink -f`), valable depuis la copie du plugin comme depuis les liens
`~/.local/bin`. Les skills gardent leur `name:` : `/pr`, `/br`, `/worktree` s'invoquent sans
préfixe tant qu'aucune autre commande ne porte ce nom (sinon `/git-nav:pr`…).

Les anciens liens `~/.claude/skills/{pr,br,worktree}/` (d'avant le plugin), devenus morts,
sont retirés par le ménage de `./install.sh` (voir [Installation des plugins](#installation-des-plugins)).

#### Installation hors de ce dépôt

Le plugin ne dépend pas du reste de la config :

```bash
claude plugin marketplace add yoannwicker/claude-tools   # ou un clone local
claude plugin install git-nav@claude-tools
```

Pour `gpr`/`gbr` dans le terminal (facultatif), passer plutôt par un clone :
`./install.sh plugin git-nav` y installe le plugin et lie `gpr`, `gbr` dans `~/.local/bin`
et `git-tools.sh` (`cd` final, alias) dans `~/.config/shell/`, à charger depuis
`~/.bashrc` s'il ne charge pas `~/.bash_aliases`.

#### `/pr`

`/pr [numéro | mots-clés]` : trouve une PR GitHub (`gh pr list`/`view`, PR ouvertes
uniquement ; sans argument, les plus récemment modifiées d'abord) — une seule
correspondance est ouverte directement, plusieurs sont proposées dans un sélecteur (les 4
premières ; les 6 suivantes listées dans la question, à taper dans « Other », plus le
nombre de PR restantes) —, la charge en contexte (description, revue, checks,
commentaires), puis demande toujours où se placer : worktree dédié (recommandé s'il y a
du travail local non commité) ou branche courante. Les outils autorisés sont listés dans le frontmatter du
`SKILL.md`. Toutes les opérations passent par le script `gpr` (sous-commandes `list`,
`view`, `where`, `worktree`, `checkout`, voir [ci-dessous](#gpr-gbr-dans-le-terminal)).
Prérequis : `gh` authentifié sur le compte qui voit le repo.

#### `/br`

`/br [nom | mots-clés]` : même parcours que `/pr` pour une branche git, locale ou
`origin` (nom exact pris directement, sinon recherche dans le nom et sélecteur ; sans
argument, dernier commit d'abord), la charge en contexte (avance/retard sur la branche
par défaut, commits propres, fichiers, PR liée), puis demande toujours où se placer :
worktree dédié ou branche courante. Toutes les opérations passent par le script `gbr`
(voir [ci-dessous](#gpr-gbr-dans-le-terminal)). Prérequis : `gh`
facultatif (PR liée).

#### `/worktree`

`/worktree [list | clear | release]` : liste les worktrees du dépôt courant avec un verdict
(`worktree-scan`), et avec `clear` supprime après confirmation ceux qui sont libres. Libre =
ni dépôt principal, ni worktree de la session, ni verrouillé, sans modifications locales,
et sans aucun processus de l'utilisateur dont le cwd est dedans (lecture de
`/proc/*/cwd` : couvre les sessions Claude, les shells et les terminaux IDE). Suppression
par `git worktree remove` sans `--force`, branches conservées, puis `git worktree prune`.

`release` libère le worktree de la session (typiquement une fois la PR terminée, que
`clear` ignore) : refus s'il est verrouillé ou a des modifications non commitées,
confirmation s'il a des commits non poussés ou pas d'upstream ; la session le quitte
(`ExitWorktree` en mode `keep` — `remove` supprimerait aussi la branche — ou `cd` vers
le dépôt principal si elle a été lancée dedans), puis `git worktree remove` depuis le
dépôt principal. La branche est conservée ; si sa PR est mergée, Claude enchaîne sur le
[ménage après un merge](#ménage-après-un-merge).
Prérequis : Linux (`/proc`).

#### Ménage après un merge

Pas de commande : le skill `branch-cleanup` (`user-invocable: false`, absent du menu `/`)
est lancé par Claude dès qu'une branche ou une PR est mergée, pour proposer de supprimer
son worktree, la branche locale, ses sauvegardes et la branche distante :

- **après un merge fait par Claude** : le hook `PostToolUse` du plugin
  (`hooks/merge-watch.py`, sur `Bash`) repère un `gh pr merge`, un `git merge <branche>`
  ou un `git push <remote> <branche>:<branche par défaut>` (merge par avance rapide après
  un rebase ; `HEAD:main` désigne la branche extraite, `git -C` compris) réussi, lance
  `gbr cleanup --dry-run` sur la branche mergée et donne le plan à Claude (pas pour
  `gh pr merge --auto`, ni `git merge --abort`/`--continue`/`--quit`, ni
  `git push --delete`/`--dry-run`/`--all`/`--mirror`, un SHA ou la branche par défaut
  poussée sur elle-même ; non inspectés : `bash -c`, `eval`, scripts, ni le dossier d'un
  `cd` qui précède) ;
- **après un merge fait ailleurs** (GitHub, terminal) : quand l'utilisateur dit qu'une
  branche ou une PR est mergée, ou quand `/pr`, `/br` ou `/worktree release` tombent sur
  une PR à l'état `MERGED` (`/pr` et `/br` enchaînent alors au lieu de proposer le checkout).

Claude montre le plan et demande *Tout supprimer*, *Local seulement* ou *Annuler*, puis
lance `gbr cleanup --yes` ; s'il est dans le worktree de la branche, il en sort d'abord
(`ExitWorktree` en mode `keep`, comme `/worktree release`). Depuis la branche par défaut
sans branche désignée, les branches locales dont la PR est mergée sont proposées.

`gbr cleanup [--dry-run | --yes] [--local] [--pr <n>] [<branche>]` (aussi dans le
terminal, où il demande lui-même confirmation) fait tout le travail ; branche par défaut :
la branche courante, `--pr` prend celle de la PR.

- **Vérification** : la PR doit être mergée (sans PR : branche entièrement contenue dans
  la base, locale ou `origin`), et la branche locale ne doit pas avoir de commit absent du
  dernier commit de la PR (récupéré par `pull/<n>/head` si besoin) ; sinon rien n'est
  supprimé. C'est ce contrôle qui autorise `git branch -D` (`-d` échoue après un squash
  ou un rebase merge).
- **Worktree** : la branche ne peut pas être supprimée tant qu'elle y est checkoutée, donc
  son worktree est supprimé d'abord (`git worktree remove` sans `--force`, puis `prune`),
  s'il est libre pour `worktree-scan` ; `dirty`, `busy` (un processus y a son dossier
  courant) ou `locked` → tout s'arrête et le worktree est gardé.
- **Ensuite** : bascule sur la base à jour (`git switch`, `git pull --ff-only`) si c'était
  la branche courante du dépôt principal (arrêt si elle a des modifications : jamais de
  stash), branche locale, sauvegardes `backup/<branche>-*` de `/git-tidy:commits` (`/` du
  nom gardé ou remplacé par `-`), puis branche distante si GitHub ne l'a pas déjà
  supprimée et sans `--local`.
- `--dry-run` affiche le plan, ou `bloqué : <raison>` avec le code 1.
- Prérequis : `gh` authentifié (état de la PR ; sans `gh`, seule la règle « contenue dans
  la base » s'applique), Linux (`/proc`, via `worktree-scan`).

#### `gpr`, `gbr` dans le terminal

Les skills reposent sur `gpr` (PR) et `gbr` (branches), qui servent aussi dans le
terminal (liens `~/.local/bin`) : même parcours — trouver, afficher, se placer dessus —
et code partagé dans `lib/git-tools.sh`. `shell/git-tools.sh` (lié dans `~/.config/shell/` par
`./install.sh plugin git-nav`, chargé par `~/.bash_aliases`, voir
[TOOLS.md](TOOLS.md#chargement-du-shell)) les enveloppe dans des fonctions shell et
ajoute des alias.

- **Où se placer** : après l'affichage, le mode interactif demande toujours : branche
  courante, worktree ou rester ici. Rien n'est demandé si l'on est déjà sur la branche.
  S'il y a du travail non commité, il est affiché et le worktree proposé en premier
  (jamais de stash). Un worktree déjà ouvert sur la branche est proposé à la place d'un
  nouveau.
- **Worktree** (sous-commande `worktree`) : réutilise le worktree déjà ouvert sur la
  branche, sinon le crée dans `<racine du dépôt principal>/.claude/worktrees/<dossier>`
  (fetch si la branche existe sur origin, `.claude/worktrees/` dans `.git/info/exclude`
  s'il n'est pas ignoré, branche locale suivie, `mise trust` si `mise.toml`) ; n'écrit que
  le chemin sur la sortie standard. Même emplacement que les worktrees de Claude, donc
  visible par `/worktree` et accepté par `EnterWorktree`.
- **Sous-commandes** `list`, `view`, `where`, `worktree`, `checkout` : non interactives, à
  sortie stable, utilisées par les skills `/pr` et `/br` ; `--help` les liste.
  `gbr cleanup` : voir [ménage après un merge](#ménage-après-un-merge).
- **Le `cd` final** : un script ne peut pas changer le dossier de son appelant ; les
  fonctions `gpr`/`gbr` passent un fichier dans `GIT_TOOLS_CD_FILE`, le script y écrit le
  worktree choisi et la fonction y fait le `cd`. Appelé directement (sans la fonction),
  le script affiche `cd <dossier>`.
- **Dans Claude**, utiliser `/pr` et `/br` plutôt que `! gpr` / `! gbr` : pas de
  clavier pour les menus, et le `cd` ne déplacerait pas la session.

`gpr` — PR GitHub (`gh` authentifié sur le compte qui voit le repo) :

- `gpr [-c] [numéro | mots-clés]` : interactif. Sans argument, PR ouvertes les plus
  récemment modifiées d'abord ; une seule correspondance est prise directement, sinon
  menu. Affiche la PR (`-c` : avec les commentaires) et ses checks, puis où se placer.
- `gpr list [recherche]` : une PR par ligne, `n titre branche auteur draft date` séparés
  par des tabulations, 50 au plus.
- `gpr view [-c] <n>` : `gh pr view` puis `gh pr checks`.
- `gpr where <n>` : `branch`, `local_branch`, `fork`, `current`, `worktree`, `dirty` en
  `clé=valeur`.
- `gpr worktree <n>` : worktree `pr-<n>`.
- `gpr checkout <n>` : `gh pr checkout` puis `git status -sb`.
- PR de fork : branche locale `pr-<n>` (fetch de `pull/<n>/head`).
- Alias : `gprs` (PR ouvertes, récentes d'abord), `gprr` (relecture demandée).

`gbr` — branches git (`gh` facultatif : PR liée dans `view`) :

- `gbr [nom | mots-clés]` : interactif. Un nom de branche existant (avec ou sans
  `origin/`) est pris directement ; sinon recherche dans le nom, une seule
  correspondance est prise directement, sinon menu. Affiche la branche, puis où se
  placer.
- `gbr list [recherche]` : `git fetch --prune` puis branches locales et `origin`
  dédoublonnées, hors branche par défaut (`origin/HEAD`, sinon `main`/`master`), dernier
  commit d'abord, filtre insensible à la casse ; une par ligne,
  `nom où date auteur suivi` séparés par des tabulations (`où` : `local`, `origin` ou
  `local+origin`), 50 au plus.
- `gbr view <branche>` : où elle existe, suivi, dernier commit, avance/retard sur la
  branche par défaut, PR liée (`gh pr list --head`, tous états), 30 derniers commits
  propres, résumé des fichiers touchés.
- `gbr where <branche>` : `branch`, `local`, `remote`, `current`, `worktree`, `dirty` en
  `clé=valeur`.
- `gbr worktree <branche>` : worktree nommé d'après la branche, `/` remplacés par `-`
  (`feat/x` → `feat-x`) ; une branche seulement locale n'est pas fetchée.
- `gbr checkout <branche>` : `git switch` (crée la branche locale suivie si elle n'existe
  que sur origin) puis `git status -sb`.
- `gbr cleanup [--dry-run | --yes] [--local] [--pr <n>] [<branche>]` : supprime une
  branche mergée, son worktree, ses sauvegardes et sa branche distante, après
  vérification ; sans `--dry-run` ni `--yes`, demande (voir
  [ménage après un merge](#ménage-après-un-merge)).
- Alias : `gbrs` (= `gbr list`).

### `git-tidy`

**Rôle** : remettre une branche au propre avant relecture ou avant merge — réécrire ses commits
(`/git-tidy:commits`), puis aligner la description de sa PR et le ticket lié sur ce qui a
changé (`/git-tidy:pr-sync`), ou les deux d'affilée (`/git-tidy:ready`). Les skills ne se lancent qu'à la demande
(`disable-model-invocation`) et n'écrivent rien hors du dépôt local sans accord.

**Fichiers** : `plugins/git-tidy/` (`skills/{commits,pr-sync,ready}/SKILL.md`) ; rien hors du
plugin. **Activé dans** : tous les profils.

**Prérequis** : `git` ; `gh` authentifié (base de la PR, `/git-tidy:pr-sync`) ; pour JIRA, un
MCP Atlassian connecté (`claude.ai Atlassian Rovo` ou `claude.ai Atlassian MCP`) ; sans lui,
seules la PR et les issues GitHub sont traitées.

#### Installation hors de ce dépôt

Le plugin ne dépend pas du reste de la config :

```bash
claude plugin marketplace add yoannwicker/claude-tools   # ou un clone local
claude plugin install git-tidy@claude-tools
```

#### `/git-tidy:commits`

`/git-tidy:commits [n] [--base <base>]` : réécrit les commits de la branche de la PR `n`,
sinon de la PR ou branche en contexte (`/git-nav:pr`, `/git-nav:br`…), sinon de la branche
courante, depuis sa base (`--base`, sinon la base de sa PR, sinon la branche par défaut
d'`origin`) sans changer le code final. Tout autre argument est refusé avec l'usage.
Refuse de partir s'il y a des modifications non commitées ou une opération git en cours.

- **Autre branche que la courante** : travaille sans changer le dossier de la session
  (`git -C`), dans le worktree déjà ouvert sur la branche s'il y en a un ; sinon passe le
  worktree principal sur la branche (retour à l'ancienne, ou au commit détaché, proposé à
  la fin), ou, s'il a du travail en cours, crée un worktree dédié
  `.claude/worktrees/pr-<n>` (ou `<branche>` sans PR), gardé à la fin — par `gpr worktree`
  ou `gbr worktree` si `git-nav` est installé, sinon à la main.
  Pas pour une PR de fork : `/git-nav:pr` d'abord. Dossier occupé par un autre processus
  (session Claude, shell, IDE ; `worktree-scan` de `git-nav` s'il est installé, sinon
  `/proc`) : *Continuer quand même*, *Worktree dédié* ou *Annuler*.
- **À jour avec `origin`** : `git rebase origin/<branche>` avant tout, pour partir de ce
  qui a été poussé ; conflit → abandon et arrêt.
- **Base introuvable** : si la base de la PR contient le texte de `--base` (`dev` →
  `develop`), elle est prise sans question ; sinon les branches d'`origin` qui le
  contiennent sont proposées.

- **Plan** : un commit par changement logique (refactoring séparé et avant le changement de
  comportement, correction d'un bug déjà présent sur la base et réglage technique —
  configuration, dépendance, build, CI — chacun dans son commit, séparés de la
  fonctionnalité, tests et doc avec leur code, commits de correction du code de la branche
  fondus), messages à la
  convention du dépôt (consignes, puis derniers commits de la base). Montré avant/après, puis
  *Appliquer*, *Ajuster* ou *Annuler* ; rien n'est proposé si l'historique est déjà propre.
  Les consignes du dépôt règlent la forme des commits, pas la décision de réécrire : un
  `fixup!` ou commit de correction restant est toujours fondu, même si le dépôt les garde
  jusqu'au merge ou déconseille le push forcé en revue (rappelé seulement avant le push).
- **Réécriture** : sauvegarde `backup/<branche>-<date>`, puis rebase non interactif (todo
  écrite par Claude, `GIT_SEQUENCE_EDITOR`) ou, pour redécouper un fichier, `reset --soft`
  et commits reconstruits par `git add`/`git apply --cached`. L'arbre final doit être
  identique à celui d'avant (`git diff` vide), sinon retour à la sauvegarde. Les commits
  de merge disparaissent (historique linéaire).
- **Push** : toujours demandé, par `--force-with-lease` sur le SHA distant connu ; pas
  proposé si quelqu'un a poussé sur la branche entre-temps.
- Propose ensuite de vérifier que chaque commit compile (`git rebase --exec`), de supprimer
  la sauvegarde, et `/git-tidy:pr-sync` si la branche a une PR (sauf lancé par `ready`).

#### `/git-tidy:pr-sync`

`/git-tidy:pr-sync [numéro]` : PR passée en argument, sinon la PR ou la branche en contexte
dans la conversation (`/git-nav:pr`, `/git-nav:br`, worktree, PR dont on vient de parler),
sinon celle de la branche courante — jamais la branche par défaut (`main`…) : demandée s'il
n'y a rien d'autre ou plusieurs candidats (sans PR : propose d'en créer une en brouillon).

- **Ticket** : cherché dans les issues que la PR ferme, puis le nom de branche, le titre, la
  description et les commits (clé JIRA `ABC-123`, issue `#123`) ; demandé s'il y en a
  plusieurs ou aucun. Lu par le MCP Atlassian (JIRA) ou `gh issue view`, puis comparé à la
  PR : critères couverts ou non, ajouts, décisions qui s'en écartent.
- **PR** : titre et description réécrits au format du dépôt (modèle de PR, consignes,
  dernières PR mergées) — pourquoi, lien vers le ticket, changements par thème, points de
  relecture, hors périmètre — en gardant ce qu'un humain y a mis et qui reste vrai.
- **Ticket** : un commentaire par défaut (lien, ce qui est livré, ce qui ne l'est pas,
  écarts) ; une modification de sa description seulement si une décision de la PR l'a
  rendue fausse ; jamais de changement de statut, d'assigné ni de sprint sans demande.
- Brouillons montrés, puis *PR et ticket*, *PR seulement*, *Ajuster* ou *Annuler* ; les
  écritures (`gh pr edit`, commentaire ou édition JIRA, `gh issue comment`/`edit`) ne sont
  pas pré-autorisées dans le skill.

#### `/git-tidy:ready`

`/git-tidy:ready [numéro]` : enchaîne obligatoirement `/git-tidy:commits` (base : celle de
la PR) puis `/git-tidy:pr-sync`, en suivant leurs `SKILL.md` (les deux skills ne sont pas
invocables par Claude). PR choisie comme pour `pr-sync` (argument, puis PR ou branche en
contexte, puis branche courante, jamais la branche par défaut). Il prépare le **merge** :
l'historique sort dans sa forme finale, sans `fixup!` restant.

- Refuse de partir sur une PR fermée ou mergée.
- La branche de la PR peut ne pas être la branche courante : `commits` (lancé avec
  `<n> --base <base de la PR>`) travaille dans son worktree.
- Sans PR : propose d'en créer une en brouillon (*Créer en brouillon* ou *Annuler*) ; elle
  est créée après `commits` (branche poussée d'abord si besoin), puis `pr-sync` continue
  sur elle.
- Si `commits` s'arrête (modifications non commitées, opération git en cours, *Annuler*,
  retour à la sauvegarde…), `ready` s'arrête aussi ; seul un historique déjà propre laisse
  passer à `pr-sync`.
- Mêmes accords que les deux skills (plan, push, publication) ; finit par un résumé :
  commits réécrits, sauvegarde, push, liens publiés.

### `notify`

**Rôle** : notifications desktop GNOME aux événements de Claude Code (fin de tour, erreur,
permission, question) ; un clic ramène la session au premier plan (fenêtre Herdr UI ou onglet
gnome-terminal).

**Fichiers** : `plugins/notify/` (`hooks/hooks.json`,
`scripts/{notify.sh,notify-click.sh,claude-notify.py}`, `setup.sh`) ; hors du plugin, le lien
`~/.local/bin/claude-notify-click` posé par `./install.sh plugin notify` pour l'extension GNOME
`claude-notify@ywicker` ([TOOLS.md](TOOLS.md#extension-gnome-claude-notifyywicker)).
**Activé dans** : tous les profils.

**Prérequis** : GNOME Shell + gnome-terminal (X11 : `xprop`), `python3-gi` avec
`Notify 0.7`, `gdbus`, `jq` ; herdr et Herdr UI facultatifs (voir [Sans et avec herdr](#sans-et-avec-herdr)). `setup/30-gnome.sh` signale ce qui manque.
Pas de tests.

#### Installation hors de ce dépôt

Le plugin ne dépend pas du reste de la config (les scripts se trouvent entre eux par
chemin relatif) :

```bash
claude plugin marketplace add yoannwicker/claude-tools   # ou un clone local
claude plugin install notify@claude-tools
```

Pour la pastille GNOME (facultative), passer plutôt par un clone : `./install.sh plugin
notify` (plugin et lien `~/.local/bin/claude-notify-click`), lier
`home/.local/share/gnome-shell/extensions/claude-notify@ywicker/` dans
`~/.local/share/gnome-shell/extensions/`, puis `gnome-extensions enable
claude-notify@ywicker` (au premier lien, GNOME Shell ne la voit qu'après une
déconnexion/reconnexion).

#### Fonctionnement

Hooks du plugin (`hooks/hooks.json`), tous sur `bash "${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh"` :
`Stop`, `StopFailure`, `Notification` (notification desktop), `UserPromptSubmit` (efface
les notifications en attente de la session). Plugin à `false` dans un profil : aucune
notification.

Chaîne : `notify.sh` (lit le JSON de l'événement, construit titre et corps — titre de la
session, dossier ou workspace herdr, branche — et rend la main tout de suite) →
`claude-notify.py` (libnotify via `gi`, affiche, mémorise la notification comme *en
attente* dans `~/.local/state/claude-notify/`, suit le clic) → `notify-click.sh` (`--open`
ramène la fenêtre Herdr UI ou l'onglet gnome-terminal de la session au premier plan,
`--clear-session` / `--clear-all` ferment les notifications en attente). Permission et
question restent à l'écran (urgence critique) ; `idle_prompt` et `auth_success` sont
ignorées.

L'extension GNOME lit le même état et appelle `notify-click.sh` via
`~/.local/bin/claude-notify-click` : hors de Claude, pas de `${CLAUDE_PLUGIN_ROOT}`, et
l'emplacement du plugin installé dépend de sa source (dossier du clone ou
`~/.claude/plugins/cache/…/<version>/`) ; le lien donne un chemin fixe.

Les anciens liens `notify.sh`, `notify-click.sh`, `claude-notify.py` de `~/.claude` et de
`~/.claude-profiles/*/` (d'avant le plugin), devenus morts, sont retirés par le ménage de
`./install.sh`. `status` note une extension GNOME inactive (`on_status`).

#### Sans et avec herdr

Le plugin marche seul ; dans un pane herdr (`HERDR_PANE_ID` posé), les scripts demandent en
plus à herdr le contexte de la session et l'utilisent au clic. Binaire : `HERDR_BIN_PATH`,
sinon `herdr` du PATH ; chaque appel est borné par `timeout 2`, un herdr injoignable ne
bloque pas le hook (on retombe sur ce qu'il sait sans herdr).

| | Sans herdr | Avec herdr |
|---|---|---|
| Titre : nom de la session | `customTitle` ou `aiTitle` du transcript, sinon nom du dossier | idem, sinon agent et titre du pane (`herdr pane get`) |
| Corps : lieu | nom du dossier (`cwd`) | « label (#n) » du workspace (`herdr workspace get`) ; dossier s'il n'a pas de label |
| Corps : branche | `git rev-parse` dans `cwd` (repli : transcript) | idem |
| Silence | jamais | pane focalisé dans herdr et fenêtre X active = un terminal ou Herdr UI (`xprop` ne dit pas lequel) |
| Gardé pour le clic (`~/.local/state/claude-notify/<id>.json`) | `tty` de l'onglet (plus haut ancêtre qui en a un), `where` | `pane_id`, `herdr`, `ws_label`, `ws_id`, `session_id` |
| Clic : 1. se placer dans la session | — | `herdr agent focus <pane_id>` : workspace, onglet et pane ; pane disparu : le pane où tourne la session (`agent_session` de `herdr pane list`, session reprise ailleurs), sinon `herdr workspace focus <ws_id>` |
| Clic : 2. Herdr UI | — | s'il tourne : `herdr-gpui window focus` sur sa fenêtre qui montre le workspace (elle suit le focus de herdr), sinon sa première fenêtre ; s'arrête là |
| Clic : 3. trouver l'onglet gnome-terminal | titre marqueur `Claude Code · <dossier> (pts/N)` écrit sur le tty (OSC 2), onglet cherché par ce titre | onglet titré `*: <label du workspace atteint>`, titre écrit par herdr (`ui.window_title`) avec ~100 ms de retard après le focus, attendu jusqu'à 1 s avant de parcourir les onglets ; workspace sans label : étape sautée |
| Clic : 4. repli | première fenêtre gnome-terminal | idem |
| Événements, urgence, effacement, extension GNOME | identiques | identiques |

Herdr UI ([TOOLS.md](TOOLS.md#herdr-ui), client graphique tiers de herdr) est détecté au clic, sans réglage : `herdr-gpui window list` échoue s'il n'est pas lancé,
et on passe à gnome-terminal. Ses notifications système (`ui.toast.delivery = "system"`) restent
coupées, pour la même raison que les toasts de herdr.

Le titre d'onglet que cherche le clic sous herdr vient de `ui.window_title`, fixé à
`"{hostname}: {workspace}"` dans `home/.config/herdr/config.toml` (voir
[TOOLS.md](TOOLS.md#herdr)) : à garder tel quel, la recherche en dépend.

Le plugin [`herdr-session`](#herdr-session) ne change rien à ce tableau : herdr reconnaît
Claude et son état en lisant l'écran du pane, l'intégration ne lui transmet que
l'identifiant de session, pour la reprise après un redémarrage. `notify` n'utilise pas non
plus les notifications propres à herdr (`ui.toast.delivery`, `off` par défaut : à laisser ainsi, sinon doublons).

### `herdr-session`

**Rôle** : signaler la session Claude au pane herdr qui l'héberge, pour que herdr la reprenne
après un redémarrage.

**Fichiers** : `plugins/herdr-session/` (`hooks/hooks.json`, `setup.sh` : `status` note
l'absence du script herdr) ; hors du plugin, le script
`~/.claude/hooks/herdr-agent-state.sh`, généré et réécrit par herdr (non versionné), et le
ménage de `setup/20-herdr.sh`. **Activé dans** : tous les profils.

**Prérequis** : herdr avec son intégration Claude (`herdr integration install claude`,
version ≥ 6 pour la reprise ; `herdr integration status` → `claude: current`). Sans le
script, ou hors d'un pane herdr, le hook ne fait rien. Pas de tests.

#### Installation hors de ce dépôt

Le plugin ne dépend pas du reste de la config :

```bash
herdr integration install claude                          # script ~/.claude/hooks/herdr-agent-state.sh
claude plugin marketplace add yoannwicker/claude-tools   # ou un clone local
claude plugin install herdr-session@claude-tools
```

`herdr integration install claude` ajoute aussi son propre hook `SessionStart` (chemin
absolu) dans `~/.claude/settings.json` : le retirer, sinon la session est signalée deux
fois (à refaire après chaque réinstallation de l'intégration, ce que fait ici
`setup/20-herdr.sh`).

#### Fonctionnement

Un hook `SessionStart` (démarrage, reprise, `/clear`, compaction, fork ; `timeout` 10 s)
lance `[ -f "$HOME/.claude/hooks/herdr-agent-state.sh" ] && bash … session || true`. Le
script de herdr ne fait rien hors d'un pane herdr (`HERDR_ENV`, `HERDR_PANE_ID`,
`HERDR_SOCKET_PATH`) ni pour un sous-agent ; sinon il envoie au socket herdr
`pane.report_agent_session` : agent `claude`, identifiant de session, chemin du transcript.

herdr garde cette référence dans la session sauvegardée. Après un redémarrage du serveur
herdr (ou de la machine), il restaure workspaces, onglets et panes, puis relance
`claude --resume <id>` dans chaque pane signalé, une fois un client attaché
(`[session] resume_agents_on_restore = true`, fixé dans `home/.config/herdr/config.toml` ;
`startup_per_agent_delay_ms`, 100 ms par défaut, espace les relances). Plugin à `false`
dans un profil : ses sessions ne sont pas signalées, herdr les restaure en simple shell.

Non vérifié : herdr relance `claude` sans `CLAUDE_CONFIG_DIR`, donc a priori sur le
profil de référence (pas par `claude-profile run`, qui appliquerait le profil par défaut) ; la
conversation est retrouvée (`projects/` est partagé entre profils).

Ménage par `setup/20-herdr.sh` (rejoué par `dot` après `herdr update`), seulement si ce
plugin est installé : tout hook `herdr-agent-state.sh` de `~/.claude/settings.json` (celui
que herdr ajoute à chaque installation, ou l'ancienne variante portable des profils) est
retiré, en écrivant à travers le lien. Sans le plugin, ce hook est gardé : c'est alors le
seul branchement herdr (`./install.sh plugin --remove herdr-session` le rappelle).
`./install.sh` installe les plugins avant de lancer `setup/`, pour que ce ménage voie le plugin.

### `build-brief`

**Rôle** : faire passer toute commande Gradle de Claude par `build-brief` (sortie de build
réduite) — consigne d'usage et garde-fou qui refuse un Gradle brut.

**Fichiers** : `plugins/build-brief/` (`instructions.md`, `hooks/hooks.json`,
`hooks/gradle-guard.py`, `tests/gradle-guard.test.sh`, `setup.sh` : `status` note
`build-brief` absent du PATH). **Activé dans** : tous les profils.

**Prérequis** : `build-brief` dans le PATH (sans lui, le garde-fou laisse tout passer) ;
`python3`. Tests : `bash plugins/build-brief/tests/gradle-guard.test.sh` (hook commande,
pas un mod : `claude plugin test` ne s'applique pas).

#### Installation hors de ce dépôt

Le plugin ne dépend pas du reste de la config :

```bash
claude plugin marketplace add yoannwicker/claude-tools   # ou un clone local
claude plugin install build-brief@claude-tools
```

Retirer une éventuelle consigne build-brief déjà présente ailleurs (`~/.claude/rules/`,
`CLAUDE.md`, bloc posé par `build-brief --global`), sinon elle est chargée deux fois.

#### Consigne

`instructions.md`, injectée par un hook `SessionStart` (démarrage, reprise, `/clear`,
compaction) comme celle d'[`intellij`](#intellij) : `build-brief gradle|./gradlew …`
pour toute commande Gradle, chaque segment d'une commande enchaînée réécrit. Pour plus de
détail, sans quitter build-brief : `--stacktrace`, puis le log brut dont il donne le
chemin, puis `build-brief --mode raw` (sortie intégrale) ; rapports de tests dans
`build/test-results/`, `build/reports/tests/`. Gradle brut seulement si `build-brief`
manque, pour `--stop`/`--status`/`--version`, ou en dernier recours avec le préfixe
`BUILD_BRIEF_BYPASS=1`. Ex-règle `~/.claude/rules/build-brief.md`, reprise de
`~/.copilot/instructions/`.

#### Garde-fou

Hook `PreToolUse` sur `Bash` (`hooks/gradle-guard.py`) : la commande est découpée en
segments (`&&`, `||`, `;`, `|`, `&`, parenthèses, `$( )`, retours à la ligne ; guillemets
respectés, corps des heredocs ignorés). Un segment dont le premier mot (après les
`VAR=…` et `time`/`nohup`/`exec`/`command`/`env`) est `gradle`, `gradlew` ou un chemin
qui finit par l'un d'eux est refusé (`permissionDecision: "deny"`). Le message donne la
commande corrigée (`build-brief rewrite`) et l'escalade ci-dessus.

Laissés passer : `build-brief` absent du PATH, segment préfixé par `BUILD_BRIEF_BYPASS=1`,
appel dont toutes les options sont `--stop`, `--status`, `--version` ou `-v`, commande
illisible (guillemet non fermé). Non inspectés : `bash -c '…'`, `eval`, scripts, builds
lancés par l'IDE.

L'ancien lien `~/.claude/rules/build-brief.md`, devenu mort, est retiré par le ménage de
`./install.sh`, puis `~/.claude/rules/` s'il est vide ; les liens `rules` des dossiers de
profil, devenus morts, disparaissent à la régénération qui suit.

### `session-analysis`

**Rôle** : analyser l'usage des agents avec [AgentsView](https://agentsview.io) — rapport
sur les 30 derniers jours (`/session-analysis:report`) et bilan de la session en cours
(`/session-analysis:session`), avec ce qui s'est amélioré ou dégradé et des pistes
d'amélioration. Les deux skills ne se lancent qu'à la demande
(`disable-model-invocation`).

**Fichiers** : `plugins/session-analysis/` (`skills/{report,session}/SKILL.md`,
`bin/agentsview-up`, `bin/session-analysis-collect`, `setup.sh` : installe AgentsView,
`status` note s'il manque ou ne tourne pas) ; hors du plugin, le binaire `agentsview`
(`~/.local/bin`, ou `/usr/local/bin` s'il est inscriptible) et ses données
(`~/.agentsview/`). **Activé dans** : tous les profils.

**Prérequis** : `python3`, `curl` (installation d'AgentsView) ; Linux ou macOS. Les
transcripts lus sont ceux de Claude Code ; les autres agents (Copilot…) ne sont vus qu'à
travers AgentsView.

#### Installation hors de ce dépôt

Le plugin ne dépend pas du reste de la config :

```bash
claude plugin marketplace add yoannwicker/claude-tools   # ou un clone local
claude plugin install session-analysis@claude-tools
curl -fsSL https://agentsview.io/install.sh | bash        # AgentsView, si absent
```

Depuis un clone, `./install.sh plugin session-analysis` fait les deux (AgentsView n'est
installé que s'il manque ; `agentsview update` le met à jour). Au retrait, AgentsView reste
installé : `status` le signale avec la commande pour l'enlever.

#### AgentsView

`agentsview-up` (dans le PATH de l'outil Bash) lance le serveur en arrière-plan
(`agentsview daemon start`) s'il ne tourne pas, attend qu'il réponde et écrit son URL
(par défaut `http://127.0.0.1:8080`, interface web comprise). Les deux skills passent par
lui.

#### Collecte

`session-analysis-collect` fixe la méthode, pour que deux rapports restent comparables :

- `report --out <dossier> [--days 30] [--top 4] [--project <p>]…` : API AgentsView
  (`/api/v1/analytics/*`, `from`/`to` explicites) en global puis pour chaque projet suivi
  — les 4 plus gros de la période en messages, ou ceux passés par `--project` (nom
  AgentsView : `claude_tools`) — et transcripts des sessions de la période
  (`agentsview session list --include-source`, dédoublonnés par `uuid`). Écrit les réponses
  brutes, `transcripts.json` et `indicators.json`, le tableau d'indicateurs (mêmes clés à
  chaque fois).
- `session --out <dossier> [<id>]` : resynchronise une session (par défaut la plus récente
  du dossier courant) et écrit `session.json`, `health.json` (note, pénalités) et
  `transcript.json`.

Compteurs des transcripts : outils appelés, premiers mots des commandes Bash de lecture
(`sed`, `grep`, `cat`, `find`, `python3`…), appels MCP IntelliJ, appels `gh`/`gpr`
(seulement quand ils sont la commande, pas un mot d'un chemin), erreurs d'outils par type
(refus d'isolation worktree, hook `[nom]`, refus de l'utilisateur par outil, classifieur
du mode auto, projet inconnu du MCP IntelliJ, échec `gh`/`gpr`), modèles.

#### `/session-analysis:report`

`/session-analysis:report [projet…] [--days N]` : collecte, puis rapport en français —
méthode, vue d'ensemble, vue par projet, évolution (amélioré / dégradé / stable),
constats avec un tableau par projet et une colonne *Concerné*, synthèse constats ×
projets, pistes d'amélioration avec l'indicateur qui dira si elles ont marché. Le skill
porte les règles d'analyse (vérifier une cause dans les transcripts : l'extrait de
`signal-sessions` est le premier message de la session, pas l'appel en échec ; « trop peu
pour conclure » sous 5 sessions notées…). Ce qui est propre au dépôt — où ranger le
rapport et ses indicateurs bruts, avec quel rapport précédent le comparer, que faire des pistes — vient de ses
consignes (`AGENTS.md`, `CLAUDE.md`) ; sans consigne, le rapport est rendu dans la
conversation. Pour ce dépôt : [docs/README.md](docs/README.md).

#### `/session-analysis:session`

`/session-analysis:session [id]` : bilan court de la session en cours (identifiant donné au
skill par `${CLAUDE_SESSION_ID}`) ou de celle passée en argument — note et pénalités,
volume, échecs et refus avec leur cause, allers-retours, qualité des prompts, respect des
consignes chargées —, puis 3 pistes au plus et un conseil pour la suite. Rendu dans la
conversation, rien n'est écrit.

### `review`

**Rôle** : revue de code par un agent dédié (contexte isolé, regard non ancré sur la
session) — relire son propre diff (`/review:diff`), relire la PR d'un collègue, ou plusieurs
PR liées ensemble (pile de PR, même sujet), et y poster les commentaires retenus
(`/review:pr`), traiter les retours reçus sur sa PR
(`/review:feedback`). Chaque point est priorisé avec un conseil et validé avant d'être
envoyé ou traité. Les skills ne se lancent qu'à la demande (`disable-model-invocation`),
y compris par [`review-watch`](#review-watch-reviewpr-auto-reviewfeedback-auto), qui les lance d'office à la demande de review
(`/review:pr-auto`) ou au retour de revue reçu sur mes PR (`/review:feedback-auto`).

**Fichiers** : `plugins/review/` (`agents/reviewer.md`,
`skills/{diff,pr,feedback,pr-auto,feedback-auto}/SKILL.md`, `validation.md` et `ticket.md`
communs aux skills, `auto.md` commun à `pr-auto` et `feedback-auto`,
`bin/{review-post,review-watch}`, `systemd/review-watch.{service,timer}`,
`tests/{review-post,review-watch}.test.sh`, `herdr/{prompt.md,profile.sh}`, `setup.sh`) ;
hors du plugin, les liens `~/.local/bin/review-watch` et
`~/.config/systemd/user/review-watch.{service,timer}` posés par `setup.sh`, le drop-in
`review-watch.timer.d/interval.conf` écrit par `review-watch interval`, la config
`~/.config/claude-tools/review-watch.json` et l'état `~/.local/state/claude-tools/review-watch/`
(non versionnés), et le profil Herdr UI facultatif
`~/.config/agent-launcher/agents/custom-reviewer/prompt.md` (voir
[Profil Herdr UI](#profil-herdr-ui)). **Activé dans** :
le profil de référence et `vidal` (pas `lean`).

**Prérequis** : `git`, `python3` ; `gh` authentifié (`/review:pr`, `/review:feedback`) ;
plugin [`git-nav`](#git-nav) pour chercher une PR par mots-clés dans `/review:pr` (`gpr`).
Lecture du ticket : MCP Atlassian (`getJiraIssue`) pour JIRA, `gh` pour une issue GitHub ;
sans eux, la revue se fait sans le ticket. Outils IntelliJ utilisés par l'agent s'ils répondent (plugin [`intellij`](#intellij)),
sinon recherche classique. Mode auto (`review-watch`) : systemd utilisateur ; herdr
facultatif (sinon analyse en fond, reprise dans `gnome-terminal`) ; `python3-gi` avec
`Notify 0.7` pour le clic des notifications (sinon `notify-send`, sans clic). Tests :
`bash plugins/review/tests/review-post.test.sh` et `bash plugins/review/tests/review-watch.test.sh`
(faux `gh`, `claude`, `herdr`, rien n'est publié ni lancé) ; pas de mod : `claude plugin test` ne s'applique pas.

#### Installation hors de ce dépôt

Le plugin ne dépend pas du reste de la config (`git-nav` seulement pour la recherche de
PR par mots-clés) :

```bash
claude plugin marketplace add yoannwicker/claude-tools   # ou un clone local
claude plugin install review@claude-tools
```

Le mode auto (`review-watch`) demande en plus ses liens hors du plugin (commande dans
`~/.local/bin`, unités systemd) : passer par un clone, `./install.sh plugin review`, puis
`review-watch enable` (ou `/review:pr-auto`, qui le propose).

#### Agent `reviewer`

Lancé par `/review:diff` et `/review:pr` (`review:reviewer`), en lecture seule (Bash
limité par consigne à `git`/`gh` en lecture). Rend du JSON : résumé, proposition de
découpage éventuelle, conformité au ticket, constats (`fichier:ligne` côté nouveau, conseil, gravité,
catégorie `bug`/`securite`/`conformite`/`lisibilite`/`refactoring`/`coherence`, scénario d'échec,
suggestion, à approfondir ou non), remarques non ancrées. Chaque constat est revérifié
contre le code par le skill avant d'être montré.

- **Périmètre** : seulement les lignes ajoutées ou modifiées ; le code autour sert à
  comprendre, jamais de cible.
- **Règles du dépôt cible** : `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING*` (racine et
  dossiers touchés) ; une règle explicite enfreinte (doc à mettre à jour, fichier à ne
  jamais versionner, convention) est un constat `conformite` indispensable.
- **Conformité au ticket** : si `/review:diff` ou `/review:pr` a trouvé un ticket
  (`ticket.md` : clé JIRA ou issue GitHub dans la branche, le titre, la description de la
  PR ou les commits ; lu avec ses commentaires et l'US parente), le diff est comparé à la
  demande — les décisions prises dans les commentaires primant sur la description. Chaque
  écart (`ajout` hors périmètre, `retrait` d'une partie demandée, `changement` de
  direction) doit être justifié (ce qui change et pourquoi) dans la description de la PR,
  un commentaire du ticket ou un message de commit : justifié, il est montré pour
  information avec sa source ; sinon c'est un point `🔎`, indispensable si un critère
  d'acceptation n'est pas tenu ou est contredit, recommandé sinon. Pas de ticket trouvé
  ou lisible : dit en une ligne, la revue continue sans.
- **Refactoring, exceptionnel (3 au plus par revue)**, dans quatre cas seulement :
  - **A.** piste soumise par le lanceur (`--refacto "<piste>"`) : évaluée (faisabilité,
    périmètre, risques) ;
  - **B.** le code ajouté tord trop l'existant (booléen ajouté pour un cas particulier,
    branche greffée au milieu d'une fonction, contrat contourné) : extension propre la
    plus petite ;
  - **C.** doublon d'un flux métier existant : même opération sur les mêmes objets
    métier, existant nommé (`fichier:ligne`) et atteignable sans nouvelle dépendance,
    proposition « utiliser `X` au lieu de ce bloc », écart de comportement explicité ;
  - **D.** renommage hors du diff pour un concept métier : clarifier un concept existant
    que le nouveau rend ambigu, ou finir un remplacement que la PR ne fait qu'en partie
    (occurrences restantes listées).

  Toujours ancré sur la ligne ajoutée, conseil au plus « recommandé ». Jamais de
  renommage hors cas D, de style ni d'« amélioration » de code non touché.
- **Découpage** : diff qui mêle plusieurs sujets fonctionnels (hors corrections de bug)
  dont l'un amène une notion très différente ou dépasse ~300 lignes ajoutées → découpage
  proposé (sujets, fichiers, ordre, dépendances), avec une forme par partie :
  - **commits ou PR** si elle est relativement proche du reste et en dépend, plus une
    **tâche à ajouter sur l'US** si le projet suit ses US dans un outil de tickets (JIRA,
    issues GitHub… : clé ou numéro dans la branche, le titre ou les commits) ;
  - **US séparée** si elle est très séparée du reste, et/ou s'il reste des points
    métier à trancher qui peuvent l'être plus tard (titre, description, points ouverts).
- **Lot de PR** (`/review:pr` sur plusieurs PR) : un agent relit chaque PR sur son seul
  diff (dans une pile, son incrément sur la PR d'en dessous ; un défaut corrigé plus haut
  dans la pile n'est qu'une remarque), les autres servant de contexte ; un agent de plus
  relit **le croisement** : seulement les constats `coherence` entre PR — contradiction
  (comportement, contrat ou règle métier changés de façon incompatible, toujours `🔎`),
  doublon, conflit de merge, et pour une pile : PR qui s'appuie sur ce que celle d'en
  dessous ne fait pas, PR qui ne marche pas mergée seule dans l'ordre, changement dans la
  mauvaise PR. Ancré sur la ligne d'une PR, l'autre côté cité (`autre`).

#### Priorisation et validation

Commune aux trois skills (`validation.md`). Conseil par point : **indispensable** (bug,
faille, règle explicite enfreinte), **recommandé**, **optionnel**, **discutable** (gain
incertain, se défend dans les deux sens), **très contestable** (goût, doute, coût
supérieur au gain) ; tri par conseil puis gravité.

- Par défaut, **en liste** : tableau numéroté puis une question — *Tout sauf « très
  contestable »* (recommandé), *Indispensables seulement*, *Tout*, ou numéros et
  reformulations en texte libre.
- **Un par un** seulement pour les points `🔎` (arbitrage métier, plusieurs solutions,
  refactoring, découpage, écart au ticket non justifié, désaccord probable) : explication,
  extrait, options, question dédiée.
- Rien n'est envoyé ni modifié avant la fin de la validation.

#### `/review:diff`

`/review:diff [base] [--refacto "<piste>"]` : commits de la branche depuis sa base
(l'argument, sinon la base de sa PR, sinon la branche par défaut d'`origin`) plus le
working tree et les fichiers non suivis. Après validation, les corrections retenues sont
appliquées dans le working tree, **sans commit ni `git add`** ; un découpage accepté donne
un plan de commits à appliquer avec [`/git-tidy:commits`](#git-tidycommits), les branches
des PR à créer, la partie à sortir pour une US séparée, et les brouillons de tâche ou
d'US à reporter dans l'outil de tickets. Un écart au ticket non justifié est soit corrigé
dans le code, soit justifié : le texte est rédigé, avec où le mettre (description de la
PR, commentaire du ticket, message de commit), rien n'est posté.

#### `/review:pr`

`/review:pr <numéro… | recherche> [--refacto "<piste>"]` : PR d'un collègue (recherche par
`gpr list`), relue sans s'y placer. Chaque point est montré **tel qu'il sera posté**
(langue de la PR, préfixe `[bloquant]`, `[nit]` ou `[question]` selon le conseil, bloc
`suggestion` pour un remplacement exact). Un écart au ticket non justifié devient une
demande de justification à l'auteur (sur sa ligne, sinon dans le corps de la review). Les
commentaires validés sont **postés
directement**, en une review `COMMENT` (jamais d'approbation ni de demande de
changements), par `review-post`.

Plusieurs PR (`/review:pr 83 84 85`, ou plusieurs choisies parmi les résultats de la
recherche) forment un **lot** relu ensemble : une **pile** (base de l'une = tête d'une
autre, rangée de bas en haut) ou des PR sur un **même sujet**, peut-être contradictoires.
Pour une seule PR comme pour un lot, les PR ouvertes de la même pile qui n'y sont pas
(`gh pr list`, de proche en proche, hors les miennes) sont proposées en plus. PR fermées,
mergées ou à moi retirées du lot ; toutes dans le dépôt courant. Un agent par PR plus un
pour le croisement (voir [Agent `reviewer`](#agent-reviewer)), lancés en parallèle ; un
seul tableau de validation (colonne `PR`, constats de croisement à la fin) ; puis une
review par PR, de bas en haut de la pile, dont le corps cite les autres PR du lot. Un
constat de croisement est posté sur la PR de sa ligne en citant l'autre côté, et la review
de l'autre PR y renvoie. Le ménage final couvre les worktrees et branches de chaque PR.

`review-post <pr> <review.json> [--replace-pending] [--dry-run]` (`bin/`, dans le PATH de
l'outil Bash) évite les deux échecs vus en publiant par `gh api` (constat 2 de
[l'analyse du 23/10](docs/analyses-sessions/2026-10-23.md)) :

- un commentaire dont la ligne n'est dans aucun hunk du diff (lignes ajoutées ou de
  contexte, côté nouveau) passe dans le corps de la review (`chemin:ligne` — texte) au lieu
  de faire échouer la publication (`Line could not be resolved`) ;
- une review en attente à soi sur la PR (qui bloque toute nouvelle review) arrête le
  script (code 3, avec son lien) ; le skill demande alors de la garder ou de la supprimer
  (`--replace-pending`).

Dernière étape, seulement si un worktree ou une branche a été créé pour la revue (par
Herdr UI, [`/git-nav:pr`](#git-nav), `gh pr checkout`, à la main…) : un worktree lié à la
tête de la PR, ouvert dans la conversation ou à la branche au nom de revue
(`agent/review-<n>-…`, `pr-<n>`…), sinon le skill demande ; et les branches de revue de
cette PR restées sans worktree. Si le worktree est propre et que le commit de chaque
branche est sur `origin`, le skill propose de supprimer le worktree et sa branche locale
ensemble (`git worktree remove` sans `--force`, `git branch -D`), en sortant d'abord la
session s'il y tourne. Un worktree ouvert dans Herdr est retiré par `herdr worktree remove`,
qui ferme son workspace mais garde la branche, supprimée juste après : si la session y
tourne, les deux sont lancés détachés en dernier (échecs dans
`~/.cache/claude-tools/review-cleanup.log`).

#### `/review:feedback`

`/review:feedback [numéro]` : une de mes PR, par défaut celle de la branche courante. Fils de
review non résolus (GraphQL `reviewThreads`, même requête que `pr-comments`), chacun
analysé avec son code (fils obsolètes revérifiés) et classé par conseil, avec une suite :
**solution** (correctif précis), **options** (2-3, compromis, recommandation), **à
discuter** (arbitrage métier, désaccord, impact large : ce qui fait hésiter et une
réponse proposée) ou **déjà fait**, plus la réponse prévue sur le fil. Options et « à
discuter » sont validés un par un.

Puis, au choix : *Corriger, répondre et pousser* (recommandé), *Corriger et répondre, sans
pousser*, *Corriger seulement*. Corrections seulement sur la branche de la PR (sinon
proposé : `/git-nav:pr <n>`), en un commit `--fixup` par commit visé (commit normal pour
un ajout), `git push` simple (à fondre plus tard avec `/git-tidy:commits`), puis réponses
sur les fils (`addPullRequestReviewThreadReply`). Aucun fil n'est résolu : c'est au
relecteur, ou à [`pr-comments`](#pr-comments).

#### `review-watch`, `/review:pr-auto`, `/review:feedback-auto`

Lancer les skills d'office depuis GitHub, dépôt par dépôt : `/review:pr` à la demande de
review, `/review:feedback` (le plan de traitement) au retour de revue reçu sur mes PR.
Rien n'est posté ni répondu sans validation dans la session lancée.

**Événements**, cherchés par `review-watch poll` (timer systemd utilisateur
`review-watch.timer`, toutes les 5 min par défaut) :

- **review** : notification GitHub `review_requested` sur la PR ouverte d'un autre (API
  `notifications`, lues comprises, depuis le passage précédent). La date de la demande vient
  de la timeline de la PR (dernier `ReviewRequestedEvent` pour moi ou une équipe) : une
  nouvelle demande (re-request) relance, une revue de ma part postée depuis la demande
  l'écarte ;
- **feedback** : review d'un autre que moi sur une de mes PR ouvertes (recherche GraphQL),
  plus récente que la dernière traitée. Elle n'est prise que 5 min après la dernière review
  reçue (`feedback_delay` en secondes dans la config), le temps que le relecteur finisse. Une
  approbation sans commentaire donne une simple notification.

**Modes**, par dépôt et par événement : `auto` (session lancée), `notify` (notification,
dont le clic lance la session ; défaut des dépôts non listés) ou `off` (rien).

- `/review:pr-auto [on|off|interval <min>]` règle `review`, `/review:feedback-auto [on|off|interval <min>]` règle
  `feedback` (procédure commune : `auto.md`). Avec `on`/`off` : le dépôt courant
  (`off` le remet en `notify`). Sans argument : choix parmi les dépôts connus, c'est-à-dire
  ceux de la config et les clones GitHub des espaces de travail de [`cl`](TOOLS.md#lanceur-cl).
  Si la surveillance est arrêtée, le skill propose `review-watch enable`.
- En terminal : `review-watch auto <owner/repo|.> on|off [review|feedback]`,
  `add <repo> [--review M] [--feedback M] [--path <clone>]`, `remove <repo>`,
  `default [--review M] [--feedback M]`, `repos`, `status`.
- `review-watch enable` : enregistre d'abord ce qui est déjà en attente, sans rien lancer
  (listé, avec la commande `launch` pour le faire), puis active le timer ; `disable`
  l'arrête. `poll --dry-run` montre ce qu'un passage ferait.
- `review-watch interval [<minutes>]` (ou `/review:pr-auto interval <minutes>`, idem avec
  `feedback-auto`) : fréquence du scan (5 par défaut, commune aux deux événements), gardée
  dans la config (`interval`, éditable à la main : `review-watch interval` sans argument
  l'affiche et l'applique) et appliquée au timer par un drop-in
  `~/.config/systemd/user/review-watch.timer.d/interval.conf` (retiré si on revient à 5 ;
  timer relancé s'il tourne).

**Lancement** (`review-watch launch <owner/repo#n | n> [review|feedback]`, appelé aussi par
le mode auto et par le clic d'une notification). Clone du dépôt : `path` de la config,
sinon cherché dans les espaces de travail de `cl` et retenu.

- **herdr tourne** (`herdr status server`) : worktree de la PR sous
  `~/.herdr/worktrees/<dépôt>/`. Pour une revue, branche `agent/review-<n>-<titre>` sur la
  tête de la PR (`pull/<n>/head`), le même nom que Herdr UI, ce qui permet à l'étape de
  ménage de `/review:pr` de la retrouver. Pour un feedback, la branche de la PR (son
  dossier si elle est déjà extraite quelque part, sinon un worktree qui suit `origin`).
  Ouvert dans un workspace herdr (ou un nouvel onglet de celui qui l'a déjà) ; le pane lance
  `claude '/review:pr <n>'` (ou `/review:feedback`) en interactif. Une notification
  l'annonce (clic : `herdr agent focus`), puis le plugin [`notify`](#notify) signale la
  question de validation.
- **Sinon, analyse en fond** : `claude -p '/review:… <n> --prepare' --session-id <uuid>`,
  détaché. Une revue tourne dans le clone (`/review:pr` ne s'y place pas) ; un feedback
  tourne là où la branche est extraite, sinon dans un worktree sous
  `~/.cache/claude-tools/review-worktrees/`. Outils limités à la lecture (`--allowedTools` :
  `git`/`gh` en lecture, `gh api graphql` compris, Agent, Read/Grep/Glob, outils de lecture
  IntelliJ et JIRA). Une fois l'analyse finie, la notification « prête à valider » (critique)
  lance au clic `review-watch resume`, qui ouvre `gnome-terminal` (réglage `terminal`
  sinon) sur `claude --resume <uuid> "Reprends à la validation…"`. `review-watch resume`
  sans argument liste les sessions prêtes ; dans un terminal, il reprend sur place.
  Journal : `~/.local/state/claude-tools/review-watch/logs/`.
- `--prepare` (argument de `/review:pr` et `/review:feedback`, pour cette analyse en fond) :
  aucune question, rien de posté ni corrigé ; le tableau de validation est préparé et la
  session s'arrête sur « Prêt pour la validation ». À la reprise, elle continue à la
  validation.
- Une session herdr encore ouverte (Claude présent dans le pane) ou une analyse en cours
  pour la même PR n'est pas doublée : nouvelle activité notifiée seulement.
- `claude` (réglage `claude` de la config, ex. `"claude-profile switch vidal"`) : le profil
  utilisé doit activer le plugin `review` (profil de référence, `vidal` ; pas `lean`).

Config `~/.config/claude-tools/review-watch.json` :
`{"repos": {"owner/repo": {"review": "auto", "feedback": "notify", "path": "…"}},
"default": {"review": "notify", "feedback": "notify"}, "interval": 5, "feedback_delay": 300,
"claude": "claude", "terminal": null}`. Les noms de dépôt ne tiennent pas compte de la casse.

Installation : `./install.sh plugin review` relie `review-watch` dans `~/.local/bin`
(chemin fixe pour systemd et les clics) et les unités dans `~/.config/systemd/user/`. Le
timer n'est activé que par `review-watch enable`. `--remove` l'arrête et retire le drop-in d'intervalle (`on_remove`), et
`status` signale une config présente avec un timer arrêté. Le service tourne avec
`KillMode=process`, pour que les analyses en fond et les notifications en attente de clic
lui survivent. Il lui faut l'environnement de la session graphique (D-Bus), que GNOME donne
au gestionnaire systemd utilisateur.

#### Profil Herdr UI

[Herdr UI](TOOLS.md#herdr-ui) (pas la TUI herdr) lit des profils de revue dans
`~/.config/agent-launcher/agents/<nom>/prompt.md` (champ *PROMPT* de sa boîte de revue de PR) :
le texte du profil est ajouté **après** son prompt intégré, qui donne la PR vérifiée (numéro,
refs, SHA, commandes `gh`/`git` pour le diff) et impose la lecture seule (rien de posté).

Le profil **custom-reviewer** y fait la même chose que `/review:pr` : Claude lit et suit
`skills/pr/SKILL.md` du plugin (le skill a `disable-model-invocation`, l'outil Skill ne peut
pas le lancer), étapes 1 à 3 telles quelles (PR de la même pile proposées en plus, agent
`review:reviewer`, vérification, validation dans le pane). Au lieu de poster directement,
il montre la ou les reviews prêtes et demande ; seul un « oui » explicite dans le pane la publie (`review-post`). L'étape de ménage
est faite telle quelle : la boîte de revue ouvre la PR dans un worktree
`~/.herdr/worktrees/<dépôt>/agent-review-<n>-…` (branche `agent/review-<n>-…`), que le skill
propose de supprimer à la fin avec sa branche, son workspace et ce pane. Les `allowed-tools`
du skill ne s'appliquent pas : les permissions sont celles de la session lancée par Herdr UI.

Fichier écrit (pas un lien) depuis le gabarit `herdr/prompt.md`, avec le chemin absolu du
plugin dans le dépôt, par `herdr/profile.sh install | remove | status` :
- proposé (question `[O/n]` dans un terminal) par `./install.sh plugin review` si Herdr UI est
  installé, et par `./setup/20-herdr.sh` si le plugin review est installé — `./install.sh`
  installe les plugins avant `setup/`, donc souvent avant Herdr UI ;
- refus retenu dans `~/.config/claude-tools/herdr-review-profile-declined` ; sans terminal ou
  après un refus, seulement signalé. `REVIEW_HERDR_PROFILE=1 ./install.sh plugin review` le
  pose sans demander et oublie le refus ;
- profil déjà là mais différent (gabarit changé, retouché à la main) : sauvegardé en
  `*.bak.<date>` puis réécrit ; `./install.sh status` le signale périmé ;
- `./install.sh plugin --remove review` le retire s'il n'a pas été modifié (sinon gardé).

## Gabarit pour un nouveau plugin

```
### <plugin>
**Rôle** : …
**Fichiers** : plugins/<plugin>/ (dont setup.sh s'il pose ou vérifie quelque chose hors de lui) ;
  hors du plugin, ce que setup.sh y pose. **Activé dans** : <profils>
**Prérequis** : … Tests : claude plugin test plugins/<plugin>
#### Installation hors de ce dépôt   (si le plugin s'utilise seul ; ./install.sh plugin <plugin> depuis un clone)
Fonctionnement, commandes, touches, configuration spécifique
(#### par partie si la section est longue).
```

Nouveau skill (`home/.claude/skills/`) : un sous-titre dans [Skills](#skills), même gabarit
(déclencheur, ce qu'il fait, prérequis).
