# Outils shell

Outils du terminal qui ne dépendent pas de Claude Code, même s'ils peuvent lui servir de
socle (voir [TOOLS.md](TOOLS.md) pour Claude et le reste). Une section par outil, même
gabarit que `TOOLS.md`.

**Chargement** : `home/.bash_aliases` ne contient rien d'autre que le chargement de
`~/.config/shell/*.sh`, un fichier par famille d'outils. Le `.bashrc` Ubuntu par défaut
source `~/.bash_aliases` (sinon y ajouter `. ~/.bash_aliases`). Fonctions et alias n'y
sont chargés que dans un shell interactif : ils n'existent pas dans les commandes `!` ni
dans le shell de Claude, qui n'utilisent que les scripts de `~/.local/bin`.

## `gpr` — PR GitHub

**Rôle** : trouver une PR ouverte, l'afficher et se placer dessus (branche courante ou
worktree). Socle du skill Claude `/pr`, qui appelle ses sous-commandes.

**Fichiers** : `home/.local/bin/gpr` (le script, toute la logique),
`home/.config/shell/git-tools.sh` (fonction enveloppe `gpr` et alias `gprs`, `gprr`).

**Prérequis** : `gh` authentifié sur le compte qui voit le repo ; `~/.local/bin` dans le
PATH.

**Installation** : `./install.sh link`.

**Fonctionnalités** :
- `gpr [-c] [numéro | mots-clés]` : interactif. Sans argument, PR ouvertes les plus
  récemment modifiées d'abord ; une seule correspondance est prise directement, sinon
  menu. Affiche la PR (`-c` : avec les commentaires) et ses checks, puis demande
  toujours où se placer : branche courante, worktree ou rester ici. S'il y a du travail
  non commité, il est affiché et le worktree proposé en premier (jamais de stash).
- Sous-commandes non interactives (utilisées par `/pr`, sortie stable) :
  - `gpr list [recherche]` : une PR par ligne, `n titre branche auteur draft date`
    séparés par des tabulations, 50 au plus ;
  - `gpr view [-c] <n>` : `gh pr view` puis `gh pr checks` ;
  - `gpr where <n>` : `branch`, `local_branch`, `fork`, `current`, `worktree`, `dirty`
    en `clé=valeur` ;
  - `gpr worktree <n>` : réutilise le worktree déjà ouvert sur la branche, sinon crée
    `<racine du dépôt principal>/.claude/worktrees/pr-<n>` (fetch, `.claude/worktrees/`
    dans `.git/info/exclude` si non ignoré, branche suivie, `mise trust`) ; n'écrit que
    le chemin sur la sortie standard. Même emplacement que les worktrees de Claude, donc
    visible par `/worktree` et accepté par `EnterWorktree` ;
  - `gpr checkout <n>` : `gh pr checkout` puis `git status -sb`.
- PR de fork : branche locale `pr-<n>` (fetch de `pull/<n>/head`).
- Le `cd` final : un script ne peut pas changer le dossier de son appelant ; la fonction
  `gpr` de `git-tools.sh` passe un fichier dans `GPR_CD_FILE`, le script y écrit le
  worktree choisi et la fonction y fait le `cd`. Appelé directement (sans la fonction),
  le script affiche `cd <dossier>`.
- Alias : `gprs` (PR ouvertes, récentes d'abord), `gprr` (relecture demandée).
- Dans Claude, utiliser `/pr` plutôt que `! gpr` : pas de clavier pour les menus, et le
  `cd` ne déplacerait pas la session.
