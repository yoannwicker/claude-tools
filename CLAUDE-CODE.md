# Claude Code

Configuration utilisateur de Claude Code et ses plugins. Les outils hors Claude (lanceur
`cl`, extension GNOME, herdr, mise) sont dans [TOOLS.md](TOOLS.md).

**Rôle** : agent de code en terminal ; ce repo porte sa configuration utilisateur
(`~/.claude`), pas la configuration des projets (`.claude/` dans chaque repo).

**Fichiers** : `home/.claude/settings.json` (le profil de référence), `profiles/*.json` (surcharges, voir [Profils](#profils)), `home/.claude/statusline-command.sh`, `statusline-ps1.sh` ;
plugins : `.claude-plugin/marketplace.json`,
`plugins/{pr-comments,intellij,profiles,git-nav,notify,herdr-session,build-brief}/` (avec
leur `setup.sh`), `install.sh plugin` (voir [Installation des plugins](#installation-des-plugins)).

**Prérequis** : `claude` installé et connecté ; `jq` et `python3` (status line) ; `gh`
authentifié (plugin [`git-nav`](#git-nav), badge PR de la status line) ; Linux + GNOME pour
les notifications (plugin [`notify`](#notify)) ;
IntelliJ ouvert avec son serveur MCP pour les outils IDE (voir [`intellij`](#intellij)) ;
`build-brief` dans le PATH pour Gradle (plugin [`build-brief`](#build-brief)).

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

Profils versionnés : `vidal` (config complète : tous les plugins, plus `superpowers`, à installer
une fois dans Claude Code : `/plugin install superpowers@claude-plugins-official`) et
`basic` (le même sans `pr-comments`). Aucun profil par défaut à l'installation : `claude`
part sur le profil de référence.

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

Les skills `/pr`, `/br` et `/worktree` sont dans le plugin [`git-nav`](#git-nav). Un skill
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

**Fichiers** : `plugins/pr-comments/`. **Activé dans** : `vidal` (pas `basic`).

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
GitHub est interrogé chaque minute pour la liste (1 point GraphQL sur 5000/h), les fils
d'une PR seulement quand elle a changé, après une écriture, ou toutes les dix minutes.

### `intellij`

**Rôle** : serveur MCP IntelliJ et consigne d'usage de ses outils, ensemble.

**Fichiers** : `plugins/intellij/`. **Activé dans** : `vidal` et `basic`.

**Prérequis** : IntelliJ ouvert avec le serveur MCP actif, sinon `claude mcp list` le montre
déconnecté.

- `.mcp.json` : serveur `intellij`, transport SSE sur `http://127.0.0.1:64342/sse`
  (plugin MCP Server d'IntelliJ). Outils exposés sous `mcp__plugin_intellij_intellij__*`.
- `instructions.md` : recherche, refactoring et diff via ces outils plutôt que
  `grep`/`find`, sauf MCP injoignable ou projet non ouvert dans l'IDE. Injectée dans le
  contexte par un hook `SessionStart` du plugin (`hooks/hooks.json`, au démarrage, à la
  reprise, après `/clear` et `/compact`) : un plugin ne porte ni `CLAUDE.md` ni rules.

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

Les profils `vidal` et `basic` du dépôt sont ceux de l'auteur : à supprimer ou garder comme
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
  profil de référence. `~/.claude/settings.json` reste le lien vers le profil de référence : une session
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
  n'y en a pas) ;
- `claude-profile current` : profil de la session (d'après `CLAUDE_CONFIG_DIR`, sinon
  `reference`) ;
- `claude-profile default [<nom>|--unset]` : affiche le profil par défaut (`reference` s'il
  n'y en a pas), ou en fait `<nom>` (il est généré) ; `reference` ou `--unset` le retire ;
  vaut pour les nouvelles sessions de `run` ;
- `claude-profile show [<nom>]` : ce qui est actif sur un profil (celui de la session par
  défaut) — plugins activés (`+`) ou non (`-`, ou `?` pour un plugin installé que le profil
  ne mentionne pas), avec `(référence : activé|désactivé)` quand la référence diffère ;
  MCP actifs (`+`) ou coupés (`-`), en tête `claude.ai` pour tous les connecteurs, avec
  `(référence : …)` quand la référence diffère (serveurs : cache de `mcp-scan`, plus ceux
  des `.mcp.json` des plugins activés) ; modèle, et la liste des plugins différents du
  profil de référence ;
- `claude-profile new <nom> [description…]` : crée `profiles/<nom>.json` avec les plugins
  du profil de référence (noms réservés : `reference`, `default`, `show`, `create`,
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
- `claude-profile run [arguments claude…]` : lance `claude` sur le profil par défaut (sinon
  le profil de référence), ou sans toucher au profil courant dans une session de profil ;
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
[`gpr`, `gbr` dans le terminal](#gpr-gbr-dans-le-terminal)).

**Fichiers** : `plugins/git-nav/` (`skills/{pr,br,worktree}/SKILL.md`,
`bin/{gpr,gbr,worktree-scan}`, `lib/git-tools.sh`, `shell/git-tools.sh`, `setup.sh`) ; hors
du plugin, les liens `~/.local/bin/{gpr,gbr}` et `~/.config/shell/git-tools.sh` (fonctions
shell `gpr`/`gbr`, alias) posés par `./install.sh plugin git-nav`. **Activé dans** : `vidal` et
`basic`.

**Prérequis** : `git` ; `gh` authentifié (`/pr`, facultatif pour `/br`) ; Linux pour
`/worktree` (`/proc`).

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
dépôt principal. La branche est conservée.
Prérequis : Linux (`/proc`).

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
- Alias : `gbrs` (= `gbr list`).

### `notify`

**Rôle** : notifications desktop GNOME aux événements de Claude Code (fin de tour, erreur,
permission, question) ; un clic ramène l'onglet gnome-terminal de la session.

**Fichiers** : `plugins/notify/` (`hooks/hooks.json`,
`scripts/{notify.sh,notify-click.sh,claude-notify.py}`, `setup.sh`) ; hors du plugin, le lien
`~/.local/bin/claude-notify-click` posé par `./install.sh plugin notify` pour l'extension GNOME
`claude-notify@ywicker` ([TOOLS.md](TOOLS.md#extension-gnome-claude-notifyywicker)).
**Activé dans** : `vidal` et `basic`.

**Prérequis** : GNOME Shell + gnome-terminal (X11 : `xprop`), `python3-gi` avec
`Notify 0.7`, `gdbus`, `jq` ; herdr facultatif (voir [Sans et avec herdr](#sans-et-avec-herdr)). `setup/30-gnome.sh` signale ce qui manque.
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
ramène l'onglet gnome-terminal de la session au premier plan via `gdbus`,
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
| Silence | jamais | pane focalisé dans herdr et fenêtre X active = un terminal (`xprop` ne dit pas lequel) |
| Gardé pour le clic (`~/.local/state/claude-notify/<id>.json`) | `tty` de l'onglet (plus haut ancêtre qui en a un), `where` | `pane_id`, `herdr`, `ws_label`, `ws_id`, `session_id` |
| Clic : 1. se placer dans la session | — | `herdr agent focus <pane_id>` : workspace, onglet et pane ; pane disparu : le pane où tourne la session (`agent_session` de `herdr pane list`, session reprise ailleurs), sinon `herdr workspace focus <ws_id>` |
| Clic : 2. trouver l'onglet gnome-terminal | titre marqueur `Claude Code · <dossier> (pts/N)` écrit sur le tty (OSC 2), onglet cherché par ce titre | onglet titré `*: <label du workspace atteint>`, titre écrit par herdr (`ui.window_title`) avec ~100 ms de retard après le focus, attendu jusqu'à 1 s avant de parcourir les onglets ; workspace sans label : étape sautée |
| Clic : 3. repli | première fenêtre gnome-terminal | idem |
| Événements, urgence, effacement, extension GNOME | identiques | identiques |

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
ménage de `setup/20-herdr.sh`. **Activé dans** : `vidal` et `basic`.

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
`build-brief` absent du PATH). **Activé dans** : `vidal` et `basic`.

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
