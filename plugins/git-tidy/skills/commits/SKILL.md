---
name: commits
description: Remettre au propre les commits d'une branche par rapport à sa base (main ou autre) — un commit par changement logique, messages à la convention du dépôt, ordre lisible — sans changer le code, avec sauvegarde et push forcé seulement sur accord
argument-hint: "[branche de base]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr view:*)
---

Argument : `$ARGUMENTS`

But : réécrire l'historique de la branche courante depuis sa base pour qu'il se relise
commit par commit. **Le code final ne change pas** : seul le découpage, l'ordre et les
messages changent. Une commande git par appel Bash, sans `cd … &&` ni enchaînement (sinon
refus en session worktree).

## 1. État de départ

- `git status --porcelain` : s'il y a des modifications non commitées, le dire et
  s'arrêter (ne jamais stasher ni commiter à la place de l'utilisateur sans accord).
- Rebase, merge ou cherry-pick en cours (`git status`) → le dire et s'arrêter.
- **Base** : l'argument s'il y en a un ; sinon la base de la PR de la branche
  (`gh pr view --json baseRefName`) ; sinon la branche par défaut d'`origin`
  (`git symbolic-ref refs/remotes/origin/HEAD`). `git fetch origin <base>`, puis
  `git merge-base HEAD origin/<base>` : c'est le point de départ de la réécriture.
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
  skill (ex. doc dans le même commit que le code).

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
reformuler un message).

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
- Si la branche a une PR : proposer `/git-tidy:pr-sync` pour remettre sa description et le
  ticket en phase.
