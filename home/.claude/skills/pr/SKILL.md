---
name: pr
description: Rechercher une PR GitHub (numéro ou mots-clés), la charger en contexte et se placer dessus (branche courante ou worktree)
argument-hint: <numéro | recherche>
allowed-tools: Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh pr diff:*), Bash(gh pr checkout:*), Bash(git status:*), Bash(git worktree list:*), Bash(git worktree add:*), Bash(git rev-parse:*), Bash(git fetch origin:*), Bash(git show-ref:*), Bash(git check-ignore:*), Bash(mise trust:*), EnterWorktree
---

Argument : `$ARGUMENTS`

## 1. Trouver la PR

- Argument numérique (`83`, `#83`) → PR n°83, passer à l'étape 2.
- Argument vide → `gh pr list --limit 20` (PR ouvertes).
- Sinon → `gh pr list --limit 20 --search "$ARGUMENTS"` (PR ouvertes, brouillons inclus ;
  jamais les fermées ou mergées).

Pour une liste :
- 0 résultat → le dire et proposer une recherche plus large, s'arrêter.
- 1 résultat → passer à l'étape 2.
- Plusieurs → afficher un tableau (#, titre, état, branche, date) et attendre que je tape
  le numéro choisi (pas de sélecteur).

## 2. Charger la PR en contexte

`gh pr view <n> --json number,title,state,isDraft,author,headRefName,baseRefName,url,body,reviewDecision,statusCheckRollup,additions,deletions,changedFiles`
puis `gh pr view <n> --comments`.

Présenter un résumé court : titre, état/draft, auteur, `head → base`, décision de revue,
checks en échec éventuels, taille (+/−, fichiers), points clés de la description et des
commentaires non résolus. Garder tout cela en contexte pour la suite.

## 3. Se placer sur la PR — toujours demander

Avant de poser la question : `git status --porcelain`, branche courante
(`git rev-parse --abbrev-ref HEAD`) et `git worktree list`.

Poser **systématiquement** la question avec `AskUserQuestion` (header « Checkout ») :
- **Worktree** — créer/réutiliser un worktree dédié. Le marquer « (Recommended) » et le
  mettre en premier s'il y a du travail local non commité.
- **Branche courante** — basculer ce checkout sur la branche de la PR. Si du travail local
  est en cours, l'indiquer clairement dans la description (le checkout peut échouer ou
  embarquer les modifs) ; ne jamais stasher ni jeter de modifs sans accord explicite.
  Le marquer « (Recommended) » s'il n'y a rien en cours.
- **Rester ici** — ne rien changer, juste garder la PR en contexte.

Si la branche de la PR est déjà la branche courante ici, ne pas poser la question : le
dire et passer à l'étape 4. Si elle est checkoutée dans un autre worktree, le signaler
dans la question et proposer ce worktree existant plutôt qu'un nouveau.

### Worktree
Choisir « Worktree » vaut autorisation : enchaîner toutes les étapes sans redemander,
jusqu'à ce que la session soit placée dans le worktree.

Si un worktree existe déjà sur la branche de la PR : passer directement à l'étape 5 avec
son chemin.

1. `git fetch origin <headRefName>` (PR depuis un fork : `git fetch origin
   pull/<n>/head:pr-<n>` et utiliser `pr-<n>` comme branche).
2. Chemin : `<racine du dépôt principal>/.claude/worktrees/pr-<n>` (emplacement que
   `EnterWorktree` accepte aussi pour les bascules suivantes).
3. Si `git check-ignore -q .claude/worktrees/x` échoue : ajouter la ligne
   `.claude/worktrees/` à `.git/info/exclude` (exclusion locale, rien de commité).
4. Si la branche locale existe (`git show-ref --verify --quiet refs/heads/<branche>`) :
   `git worktree add <chemin> <branche>`, sinon
   `git worktree add --track -b <branche> <chemin> origin/<branche>`.
5. **Basculer la session** : appeler l'outil `EnterWorktree` avec `path: <chemin>` (charger
   son schéma via ToolSearch `select:EnterWorktree` si besoin). Ne pas se contenter d'un
   `cd`.
6. Si un `mise.toml` est présent : `mise trust` dans le worktree.
7. Rappeler en une ligne que `ExitWorktree` (action `keep`) ramène au dossier d'origine.

### Branche courante
`gh pr checkout <n>`, puis `git status -sb` pour confirmer (à jour / en retard sur origin).

## 4. Enchaîner

Terminer par une ligne indiquant où l'on est (branche + dossier) et attendre l'instruction
suivante (revue, correction d'un commentaire, lancer les tests…), en s'appuyant sur le
contexte de la PR chargé à l'étape 2.
