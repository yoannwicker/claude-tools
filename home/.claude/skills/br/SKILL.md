---
name: br
description: Rechercher une branche git (nom ou mots-clés, locale ou origin), la charger en contexte et se placer dessus (branche courante ou worktree)
argument-hint: [nom | recherche]
allowed-tools: Bash(gbr:*), EnterWorktree
---

Argument : `$ARGUMENTS`

Tout passe par le script `gbr` (`~/.local/bin/gbr`, `gbr --help`), que l'utilisateur
emploie aussi dans son terminal : ne pas refaire à la main avec `git`/`gh` ce qu'une
sous-commande fait déjà. Un nom peut s'écrire avec ou sans `origin/`.

## 1. Trouver la branche

- Argument qui est un nom de branche existant (`gbr where <arg>` réussit) → étape 2.
- Sinon → `gbr list $ARGUMENTS` (fetch puis branches locales et `origin` dédoublonnées,
  hors branche par défaut, dernier commit d'abord ; l'argument filtre le nom, insensible
  à la casse). Une branche par ligne, colonnes séparées par des tabulations :
  `nom où date auteur suivi` (`où` : `local`, `origin` ou `local+origin` ; `suivi` :
  `[ahead 1, behind 2]` ou vide).

`gbr list` renvoie jusqu'à 50 branches pour connaître le total, mais on n'en montre que
10 au plus (4 options + 6 dans la liste) ; les autres sont seulement comptées.

Pour une liste :
- 0 résultat → le dire et proposer une recherche plus large, s'arrêter.
- 1 résultat → passer directement à l'étape 2, sans rien demander.
- Plusieurs → sélecteur `AskUserQuestion` (header « Branche »), une option par branche :
  label `<nom tronqué>`, description `<où> · <date> · <auteur>` (+ suivi s'il y en a un),
  sans « (Recommended) ».
  - Le sélecteur est limité à 4 options : les 4 premières branches (dans l'ordre
    renvoyé) sont les options. Jusqu'à 4 résultats, la question est « Quelle branche
    charger ? ». Au-delà, la question commence par une liste compacte des suivantes
    (branches 5 à 10) : une ligne par branche, sans ligne vide entre elles, au format
    `<nom> · <date>`. S'il y a plus de 10 résultats, ajouter obligatoirement une
    dernière ligne `… et <k> autres branches` (k = total − 10 ; si `gbr list` a renvoyé
    50 lignes, écrire `… et 40+ autres branches`). Puis une ligne vide et « Quelle
    branche charger ? (« Other » permet de taper le nom d'une branche de la liste
    ci-dessus) ».
  - Le nom choisi (option ou saisie dans « Other ») → étape 2.

## 2. Charger la branche en contexte

`gbr view <branche>` : où elle existe, suivi, dernier commit, avance/retard sur la
branche par défaut, PR liée éventuelle, commits propres à la branche, fichiers touchés.

Présenter un résumé court : avance/retard, nombre de commits et ce qu'ils font, taille
(fichiers, +/−), PR liée (si elle existe, signaler que `/pr <n>` charge sa revue et ses
commentaires). Garder tout cela en contexte pour la suite.

## 3. Se placer sur la branche — toujours demander

Avant de poser la question : `gbr where <branche>`, qui renvoie en `clé=valeur` la
branche (`branch`), si elle existe en local (`local`) et sur origin (`remote`), la
branche courante (`current`), le worktree déjà ouvert sur la branche (`worktree`, vide
sinon) et le nombre de fichiers modifiés ici (`dirty`).

Si `current` = `branch` : ne pas poser la question, le dire et passer à l'étape 4.

Sinon, poser **systématiquement** la question avec `AskUserQuestion` (header « Checkout ») :
- **Worktree** — créer/réutiliser un worktree dédié. Le marquer « (Recommended) » et le
  mettre en premier si `dirty` > 0. Si `worktree` n'est pas vide, le signaler et proposer
  ce worktree existant plutôt qu'un nouveau.
- **Branche courante** — basculer ce checkout sur la branche. Si `dirty` > 0, l'indiquer
  clairement dans la description (le checkout peut échouer ou embarquer les modifs) ;
  ne jamais stasher ni jeter de modifs sans accord explicite. Le marquer
  « (Recommended) » si `dirty` = 0.
- **Rester ici** — ne rien changer, juste garder la branche en contexte.

### Worktree
Choisir « Worktree » vaut autorisation : enchaîner sans redemander.

1. `gbr worktree <branche>` : réutilise le worktree existant, sinon le crée dans
   `<racine du dépôt principal>/.claude/worktrees/<branche, / remplacés par ->` (fetch,
   exclusion locale, branche suivie, `mise trust`). Sa sortie standard est le chemin,
   seul.
2. **Basculer la session** : appeler l'outil `EnterWorktree` avec `path: <chemin>` (charger
   son schéma via ToolSearch `select:EnterWorktree` si besoin). Ne pas se contenter d'un
   `cd`.
3. Rappeler en une ligne que `ExitWorktree` (action `keep`) ramène au dossier d'origine.

### Branche courante
`gbr checkout <branche>` (`git switch`, qui crée la branche locale suivie si elle n'existe
que sur origin, puis `git status -sb` pour confirmer à jour / en retard sur origin).

## 4. Enchaîner

Terminer par une ligne indiquant où l'on est (branche + dossier) et attendre l'instruction
suivante, en s'appuyant sur le contexte de la branche chargé à l'étape 2.
