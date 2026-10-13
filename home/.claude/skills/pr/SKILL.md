---
name: pr
description: Rechercher une PR GitHub (numéro ou mots-clés), la charger en contexte et se placer dessus (branche courante ou worktree)
argument-hint: [numéro | recherche]
allowed-tools: Bash(gpr:*), EnterWorktree
---

Argument : `$ARGUMENTS`

Tout passe par le script `gpr` (`~/.local/bin/gpr`, `gpr --help`), que l'utilisateur
emploie aussi dans son terminal : ne pas refaire à la main avec `gh`/`git` ce qu'une
sous-commande fait déjà.

## 1. Trouver la PR

- Argument numérique (`83`, `#83`) → PR n°83, passer à l'étape 2.
- Sinon → `gpr list $ARGUMENTS` (sans argument : PR ouvertes les plus récemment modifiées
  d'abord ; avec : recherche GitHub, brouillons inclus, jamais les fermées ou mergées).
  Une PR par ligne, colonnes séparées par des tabulations :
  `numéro titre branche auteur draft date`.

`gpr list` renvoie jusqu'à 50 PR pour connaître le total, mais on n'en montre que 10 au
plus (4 options + 6 dans la liste) ; les autres sont seulement comptées.

Pour une liste :
- 0 résultat → le dire et proposer une recherche plus large, s'arrêter.
- 1 résultat → passer directement à l'étape 2, sans rien demander.
- Plusieurs → sélecteur `AskUserQuestion` (header « PR »), une option par PR :
  label `#<n> <titre tronqué>`, description `<branche> · <auteur> · <date>` (+ « draft »
  si brouillon), sans « (Recommended) ».
  - Le sélecteur est limité à 4 options : les 4 premières PR (dans l'ordre renvoyé) sont
    les options. Jusqu'à 4 résultats, la question est « Quelle PR charger ? ».
    Au-delà, la question commence par une liste compacte des suivantes (PR 5 à 10) :
    une ligne par PR, sans ligne vide entre elles, au format
    `#<n> <titre tronqué à ~60 caractères>`. S'il y a plus de 10 résultats, ajouter
    obligatoirement une dernière ligne `… et <k> autres PR` (k = total − 10 ; si
    `gpr list` a renvoyé 50 lignes, écrire `… et 40+ autres PR`). Puis une ligne vide et
    « Quelle PR charger ? (« Other » permet de taper le numéro d'une PR de la liste
    ci-dessus) ».
  - Le numéro choisi (option ou saisie dans « Other ») → étape 2.

## 2. Charger la PR en contexte

`gpr view -c <n>` : description, état, revue, taille, commentaires, puis checks.

Présenter un résumé court : titre, état/draft, auteur, `head → base`, décision de revue,
checks en échec éventuels, taille (+/−, fichiers), points clés de la description et des
commentaires non résolus. Garder tout cela en contexte pour la suite.

## 3. Se placer sur la PR — toujours demander

Avant de poser la question : `gpr where <n>`, qui renvoie en `clé=valeur` la branche de
la PR (`branch`), la branche locale à utiliser (`local_branch`, `pr-<n>` pour une PR de
fork), la branche courante (`current`), le worktree déjà ouvert sur la branche
(`worktree`, vide sinon) et le nombre de fichiers modifiés ici (`dirty`).

Si `current` = `local_branch` : ne pas poser la question, le dire et passer à l'étape 4.

Sinon, poser **systématiquement** la question avec `AskUserQuestion` (header « Checkout ») :
- **Worktree** — créer/réutiliser un worktree dédié. Le marquer « (Recommended) » et le
  mettre en premier si `dirty` > 0. Si `worktree` n'est pas vide, le signaler et proposer
  ce worktree existant plutôt qu'un nouveau.
- **Branche courante** — basculer ce checkout sur la branche de la PR. Si `dirty` > 0,
  l'indiquer clairement dans la description (le checkout peut échouer ou embarquer les
  modifs) ; ne jamais stasher ni jeter de modifs sans accord explicite. Le marquer
  « (Recommended) » si `dirty` = 0.
- **Rester ici** — ne rien changer, juste garder la PR en contexte.

### Worktree
Choisir « Worktree » vaut autorisation : enchaîner sans redemander.

1. `gpr worktree <n>` : réutilise le worktree existant, sinon le crée dans
   `<racine du dépôt principal>/.claude/worktrees/pr-<n>` (fetch, exclusion locale,
   branche suivie, `mise trust`). Sa sortie standard est le chemin, seul.
2. **Basculer la session** : appeler l'outil `EnterWorktree` avec `path: <chemin>` (charger
   son schéma via ToolSearch `select:EnterWorktree` si besoin). Ne pas se contenter d'un
   `cd`.
3. Rappeler en une ligne que `ExitWorktree` (action `keep`) ramène au dossier d'origine.

### Branche courante
`gpr checkout <n>` (`gh pr checkout` puis `git status -sb` pour confirmer à jour / en
retard sur origin).

## 4. Enchaîner

Terminer par une ligne indiquant où l'on est (branche + dossier) et attendre l'instruction
suivante (revue, correction d'un commentaire, lancer les tests…), en s'appuyant sur le
contexte de la PR chargé à l'étape 2.
