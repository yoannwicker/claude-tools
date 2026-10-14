# Outils

Outils du terminal et du poste, hors Claude Code, même s'ils peuvent lui servir de socle
(la configuration de Claude et ses plugins : [CLAUDE-CODE.md](CLAUDE-CODE.md)). Une section
par outil, même gabarit (voir [Gabarit pour un nouvel outil](#gabarit-pour-un-nouvel-outil)).

## Chargement du shell

`home/.bash_aliases` ne contient rien d'autre que le chargement de
`~/.config/shell/*.sh`, un fichier par famille d'outils. Le `.bashrc` Ubuntu par défaut
source `~/.bash_aliases` (sinon y ajouter `. ~/.bash_aliases`). Fonctions et alias n'y
sont chargés que dans un shell interactif : ils n'existent pas dans les commandes `!` ni
dans le shell de Claude, qui n'utilisent que les scripts de `~/.local/bin`.
Seule exception côté Claude : `claude-profile.sh`, qui fait passer `claude` par
`claude-profile run` (voir [CLAUDE-CODE.md](CLAUDE-CODE.md#bascule-depuis-une-session)).

## Lanceur `cl`

**Rôle** : lanceur de Claude Code sur un projet des espaces de travail choisis.

**Fichiers** : `home/.local/bin/cl` (espaces de travail dans `~/.config/cl/workspaces`,
non versionné).

**Prérequis** : `claude` ; `claude-profile` (voir [CLAUDE-CODE.md](CLAUDE-CODE.md#claude-profile)).

**Installation** : `./install.sh link && ./setup/50-cl.sh`.

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
profil (voir [`profiles`](CLAUDE-CODE.md#profiles)).

## Outils git : partie commune

`gpr` (PR) et `gbr` (branches) suivent le même parcours — trouver, afficher, se placer
dessus — et partagent leur code.

**Fichiers** : `home/.local/lib/git-tools.sh` (fonctions sourcées par les deux scripts,
via le chemin réel du script), `home/.config/shell/git-tools.sh` (fonctions enveloppes
`gpr`, `gbr` et alias).

**Commun aux deux** :
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
  sortie stable, utilisées par les skills Claude `/pr` et `/br` ; `--help` les liste.
- **Le `cd` final** : un script ne peut pas changer le dossier de son appelant ; les
  fonctions `gpr`/`gbr` passent un fichier dans `GIT_TOOLS_CD_FILE`, le script y écrit le
  worktree choisi et la fonction y fait le `cd`. Appelé directement (sans la fonction),
  le script affiche `cd <dossier>`.
- **Dans Claude**, utiliser `/pr` et `/br` plutôt que `! gpr` / `! gbr` : pas de
  clavier pour les menus, et le `cd` ne déplacerait pas la session.

## `gpr` — PR GitHub

**Rôle** : trouver une PR ouverte, l'afficher et se placer dessus. Socle du skill `/pr`.

**Fichiers** : `home/.local/bin/gpr` + la partie commune ci-dessus.

**Prérequis** : `gh` authentifié sur le compte qui voit le repo ; `~/.local/bin` dans le
PATH.

**Installation** : `./install.sh link`.

**Fonctionnalités** :
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

## `gbr` — branches git

**Rôle** : trouver une branche (locale ou origin), l'afficher et se placer dessus. Socle
du skill `/br`.

**Fichiers** : `home/.local/bin/gbr` + la partie commune ci-dessus.

**Prérequis** : `git` ; `gh` facultatif (PR liée dans `view`) ; `~/.local/bin` dans le
PATH.

**Installation** : `./install.sh link`.

**Fonctionnalités** :
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

## Extension GNOME `claude-notify@ywicker`

**Rôle** : pastille dans le panneau GNOME avec le nombre de notifications Claude Code en
attente ; menu pour revenir sur une session ou tout effacer.

**Fichiers** : `home/.local/share/gnome-shell/extensions/claude-notify@ywicker/`
(`extension.js`, `metadata.json`, `stylesheet.css`).

**Prérequis** : GNOME Shell 46 (`shell-version` dans `metadata.json`), les scripts de
notification de Claude ([CLAUDE-CODE.md](CLAUDE-CODE.md#notifications-desktop)) (l'extension appelle `~/.claude/notify-click.sh`).

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
  `settings.json` avec un **chemin absolu**. Les profils (`profiles/*.json`, voir [CLAUDE-CODE.md](CLAUDE-CODE.md#profils)) portent la variante
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
