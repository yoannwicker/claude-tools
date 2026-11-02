---
name: commits
description: Remettre au propre les commits d'une branche par rapport à sa base (main ou autre) — un commit par changement logique, messages à la convention du dépôt, ordre lisible — sans changer le code, avec sauvegarde et push forcé seulement sur accord
argument-hint: "[numéro de PR] [--base <branche de base>]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr view:*)
---

Argument : `$ARGUMENTS`

But : réécrire l'historique d'une branche (celle d'une PR, sinon celle en contexte, sinon
la branche courante) depuis sa base pour qu'il se relise commit par commit. **Le code
final ne change pas** : seul le découpage, l'ordre et les messages changent. Une commande
git par appel Bash, sans `cd … &&` ni enchaînement (sinon refus en session worktree).

## 1. État de départ

- **Arguments** : au plus un numéro de PR (`152` ou `#152`) et `--base <base>`. Tout autre
  argument (mot seul, option inconnue, deux numéros) → s'arrêter en le disant :
  « Argument non reconnu : `<arg>`. Usage : `/git-tidy:commits [n] [--base <base>]` »
  (pour un mot seul, rappeler `--base <arg>` s'il voulait désigner la base).
- **Branche**, dans l'ordre :
  1. numéro en argument → la branche de cette PR ;
  2. sinon la PR ou la branche en contexte dans la conversation (chargée par
     `/git-nav:pr` ou `/git-nav:br`, worktree ouvert, PR ou branche dont on vient de
     parler), sauf la branche par défaut du dépôt : sa PR (`gh pr view <branche>`), sinon
     la branche seule ;
  3. sinon la branche courante.

  Avec une PR : `gh pr view <n|branche> --json number,state,baseRefName,headRefName,isCrossRepository` ;
  PR introuvable → le dire et s'arrêter ; fermée ou mergée → le dire et s'arrêter.
- **Dossier de travail** : là où la branche est extraite, sans changer le dossier de la
  session.
  - Branche courante → le dossier courant.
  - Sinon, `git worktree list --porcelain` : si un worktree a la branche extraite
    (`branch refs/heads/<branche>`) → ce worktree.
  - Sinon, PR d'un fork (`isCrossRepository`) : le dire et s'arrêter (proposer
    `/git-nav:pr <n>`). Sinon `git fetch origin <branche>`, puis selon le **worktree
    principal** (première entrée de `git worktree list --porcelain`) :
    - **sans travail en cours** (`git -C <principal> status --porcelain` vide, aucun
      rebase, merge ou cherry-pick en cours) : y changer de branche,
      `git -C <principal> switch <branche>` (crée la branche locale suivant
      `origin/<branche>` si besoin), en notant ce qui était extrait avant (`<origine>` :
      la branche, ou le SHA si `HEAD` était détaché) ;
    - **avec travail en cours** : le worktree dédié de la branche,
      `<principal>/.claude/worktrees/pr-<n>` (sans PR : `<branche>` avec `/` remplacés par
      `-`), celui que `/git-nav:pr` et `/git-nav:br` réutiliseront. Chemin déjà enregistré
      mais dossier absent (`prunable` dans `git worktree list --porcelain`) →
      `git worktree prune` d'abord ; dossier présent mais pas enregistré → le dire et
      s'arrêter (ne jamais le supprimer). Puis :
      - plugin `git-nav` installé (`gpr` et `gbr` dans le `PATH`) : `gpr worktree <n>`
        (sans PR : `gbr worktree <branche>`), qui fait le fetch, l'exclusion de
        `.claude/worktrees/` et le `mise trust` ; sa sortie standard est le chemin ;
      - sinon à la main : si `.claude/worktrees/` n'est pas ignoré
        (`git -C <principal> check-ignore -q .claude/worktrees/x` échoue), l'ajouter à
        `<git -C <principal> rev-parse --git-common-dir>/info/exclude` (une autorisation
        sera demandée) ; puis `git worktree add <dossier> <branche>` si la branche existe
        en local (`git rev-parse --verify refs/heads/<branche>`), sinon
        `git worktree add --track -b <branche> <dossier> origin/<branche>`.
  - **Dossier occupé** : avant de travailler dans un worktree existant ou de changer la
    branche du worktree principal, chercher les processus de l'utilisateur dont le
    répertoire courant est dans ce dossier (hors worktrees imbriqués
    `.claude/worktrees/…` et hors cette session) : autre session Claude, shell, IDE.
    Si le plugin `git-nav` est installé (`worktree-scan` dans le `PATH`), son verdict
    `busy` le donne pour un worktree secondaire ; sinon, et toujours pour le worktree
    principal, le faire à la main (`readlink /proc/<pid>/cwd` sur les processus de
    l'utilisateur, `/proc/<pid>/comm` pour les nommer). Occupé → `AskUserQuestion`
    (header « Occupé », processus en description) : **Continuer quand même** /
    **Worktree dédié** (seulement pour le worktree principal : passer au cas « avec
    travail en cours ») / **Annuler**.
  - Hors du dossier courant, le dire en une ligne (branche + dossier) avant de continuer.
    Toute commande git de la suite s'y lance par `git -C <dossier> …` (y compris
    `git status`, le rebase et le push) ; « la branche » désigne alors celle de ce dossier.
- `git status --porcelain` : s'il y a des modifications non commitées, le dire et
  s'arrêter (ne jamais stasher ni commiter à la place de l'utilisateur sans accord).
- Rebase, merge ou cherry-pick en cours (`git status`) → le dire et s'arrêter.
- **À jour avec `origin`** : si `origin/<branche>` existe (`git fetch origin <branche>`),
  `git rebase origin/<branche>` — la branche rattrape ce qui a été poussé, ses commits
  locaux non poussés se replacent dessus. Le dire s'il a fait quelque chose. Conflit →
  `git rebase --abort`, le dire et s'arrêter.
- **Base** : `--base <base>` s'il est donné ; sinon la base de la PR de la branche
  (`baseRefName` ci-dessus, ou `gh pr view --json baseRefName`) ; sinon la branche par
  défaut d'`origin` (`git symbolic-ref refs/remotes/origin/HEAD`).
  - `--base` qui n'existe pas sur `origin` (`git ls-remote --heads origin <base>` vide) :
    si la base de la PR contient le texte tapé (sans tenir compte de la casse, ex. `dev`
    pour `develop`), la prendre sans rien demander ; sinon proposer les branches
    d'`origin` qui le contiennent (`git ls-remote --heads origin`), `AskUserQuestion`
    (header « Base », 4 au plus, la plus proche en premier) ; aucune → le dire et
    s'arrêter.
  - `git fetch origin <base>`, puis `git merge-base HEAD origin/<base>` : c'est le point
    de départ de la réécriture.
- Sur la base elle-même, ou aucun commit depuis la base → le dire et s'arrêter.

## 2. Comprendre la branche

- `git log --reverse --format='%h %s%n%b' <merge-base>..HEAD`, `git diff --stat
  <merge-base> HEAD`, puis le diff complet (`git diff <merge-base> HEAD`), et `git show`
  d'un commit quand il faut savoir ce qu'il contient.
- Commits de merge dans la plage (`git log --merges <merge-base>..HEAD`) : la réécriture
  les supprime (historique linéaire). Le signaler dans le plan.
- **Convention des messages** : consignes du dépôt (`AGENTS.md`, `CLAUDE.md`,
  `CONTRIBUTING.md`, hooks `commit-msg`, `commitlint`), puis les 20 derniers commits de la
  base (`git log -20 --format=%s origin/<base>`) : langue, préfixe (gitmoji, Conventional
  Commits, clé de ticket `ABC-123`), longueur, corps. Les consignes du dépôt priment sur ce
  skill pour la **forme** des commits (messages, découpage : ex. doc dans le même commit
  que le code), jamais pour décider **s'il faut** réécrire : lancer ce skill, c'est vouloir
  réécrire. Une consigne qui garde les `fixup!` jusqu'au merge ou déconseille le push
  forcé pendant la revue ne dispense pas de les fondre ; elle se rappelle seulement au
  moment de demander le push (étape 5).

## 3. Proposer un découpage

Principes :
- un commit = un changement logique, qui se comprend seul et, autant que possible, compile
  et passe les tests seul ;
- refactoring (sans changement de comportement) séparé du changement de comportement, et
  avant lui ;
- correction d'un bug dans du code déjà présent sur la base dans son propre commit, séparé
  du reste (il doit pouvoir être relu, cherry-pické ou reverté seul) ; à ne pas confondre
  avec une correction de code introduit par la branche, qui est fondue dans son commit ;
- réglage technique (configuration, dépendance, build, CI) séparé de la fonctionnalité
  (US) qu'il accompagne ;
- tests et doc dans le commit du code qu'ils couvrent ;
- les commits de correction (`fix typo`, `wip`, `review`, `fixup!`) fondus dans le commit
  qu'ils corrigent ;
- formatage ou renommage de masse dans un commit à part ;
- ordre de lecture : préparatifs, puis cœur du changement, puis branchements et nettoyage.

Si l'historique respecte déjà ces principes, le dire et s'arrêter (au plus proposer de
reformuler un message). Un historique qui contient encore un commit de correction
(`fixup!`, `squash!`, `wip`, `review`…) ne les respecte jamais, quoi que disent les
consignes du dépôt.

Sinon présenter :
- **avant** : la liste actuelle (`<sha> <sujet>`) ;
- **après** : chaque commit cible, numéroté, avec son message complet, ses fichiers (et
  quelles parties d'un fichier s'il est partagé entre plusieurs commits), et les commits
  d'origine qu'il reprend ;
- ce qui se perd : commits de merge, messages fusionnés.

Puis `AskUserQuestion` (header « Commits ») : **Appliquer** / **Ajuster** (l'utilisateur
dit quoi, on repropose) / **Annuler**.

## 4. Réécrire

1. **Sauvegarde** : `git branch backup/<branche>-<AAAAMMJJ-HHMM> HEAD`, et noter le SHA de
   `HEAD` (`<avant>`).
2. Selon le plan :
   - **Commits pris en entier** (réordonner, fusionner, reformuler) : rebase non
     interactif à partir d'une todo écrite dans le scratchpad —
     `GIT_SEQUENCE_EDITOR="cp <todo>" git rebase -i <merge-base>`, avec `pick`, `fixup`,
     `squash`, et pour reformuler `pick` suivi de `exec git commit --amend -F <message>`.
   - **Commits redécoupés** (une partie d'un fichier va dans un commit, le reste ailleurs) :
     `git reset --soft <merge-base>`, `git reset` (tout désindexer), puis pour chaque commit
     cible : `git add -- <fichiers>` pour les fichiers entiers, `git apply --cached <patch>`
     pour une partie de fichier (patch extrait de `git diff -- <fichier>` et réduit aux
     hunks voulus), puis `git commit -F <message>`. Jamais `git add -p` ni `-i`
     (interactifs).
   - Messages écrits dans des fichiers du scratchpad, passés par `-F`.
3. Conflit pendant un rebase : le résoudre s'il est mécanique (même contenu final), sinon
   `git rebase --abort`, le dire et proposer un autre découpage.
4. **Vérification obligatoire** : `git diff <avant> HEAD` doit être vide. Sinon, le
   montrer, revenir à la sauvegarde (`git reset --hard <avant>`, accord non nécessaire :
   c'est l'état d'origine) et s'arrêter.
5. Montrer le résultat : `git log --oneline <merge-base>..HEAD`.
6. Proposer (sans l'imposer) de vérifier que chaque commit compile, avec la commande de
   build/test rapide du projet :
   `git rebase --exec "<commande>" <merge-base>` (Gradle : passer par `build-brief`).

## 5. Pousser — toujours demander

- Pas d'upstream (`git rev-parse --abbrev-ref @{u}` échoue) : proposer
  `git push -u origin <branche>`.
- Upstream existant : la réécriture a fait diverger la branche. Si `origin/<branche>`
  contient des commits absents de `<avant>` (`git log <avant>..origin/<branche>`), quelqu'un
  a poussé entre-temps : le dire et ne pas proposer de push forcé.
- Sinon `AskUserQuestion` (header « Push ») : **Pousser** avec
  `git push --force-with-lease=<branche>:<sha d'origin/<branche>> origin <branche>`
  (jamais `--force` seul) / **Plus tard**.

## 6. Fin

- Rappeler la sauvegarde `backup/…` et la commande pour revenir en arrière
  (`git reset --hard backup/…`), et proposer de la supprimer une fois le résultat validé
  (`git branch -D`, seulement sur accord).
- Worktree principal passé sur la branche à l'étape 1 : le rappeler, et proposer d'y
  revenir sur `<origine>` (`git -C <principal> switch <origine>`, ou
  `switch --detach <sha>` si `HEAD` était détaché), y compris quand on s'arrête en route.
- Worktree créé à l'étape 1 : il reste. Le dire, avec comment le rouvrir
  (`/git-nav:pr <n>` ou `/git-nav:br <branche>` si le plugin `git-nav` est installé,
  sinon `EnterWorktree` sur son chemin) et le retirer (`/git-nav:worktree clear`, sinon
  `git worktree remove <dossier>`).
- Si la branche a une PR : proposer `/git-tidy:pr-sync` pour remettre sa description et le
  ticket en phase.
