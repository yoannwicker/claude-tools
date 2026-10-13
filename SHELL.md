# Outils shell

Outils du terminal qui ne dépendent pas de Claude Code, même s'ils peuvent lui servir de
socle (voir [TOOLS.md](TOOLS.md) pour Claude et le reste). Une section par outil, même
gabarit que `TOOLS.md`.

**Chargement** : `home/.bash_aliases` ne contient rien d'autre que le chargement de
`~/.config/shell/*.sh`, un fichier par famille d'outils. Le `.bashrc` Ubuntu par défaut
source `~/.bash_aliases` (sinon y ajouter `. ~/.bash_aliases`). Fonctions et alias n'y
sont chargés que dans un shell interactif : ils n'existent pas dans les commandes `!` ni
dans le shell de Claude, qui n'utilisent que les scripts de `~/.local/bin`.

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
