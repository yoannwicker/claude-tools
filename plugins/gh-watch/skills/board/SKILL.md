---
name: board
description: Faire le point sur les PR ouvertes qui me concernent — sur le dépôt courant, un dépôt donné ou tous (--all : seulement ce sur quoi j'ai à agir, dépôts filtrés par gh-watch set board) — ce qui est à moi (retours à traiter, approuvée à préparer, à faire relire, relecture demandée…), ce qui attend les autres, depuis quand, et l'action proposée pour chacune ; --auto : le suivi par les watchers (review-watch, tidy-watch) ; --missed : les actions qu'ils ont manquées
argument-hint: "[<owner/repo> | --all] [--full | --auto | --missed]"
disable-model-invocation: true
allowed-tools: Bash(gh-watch board:*), Bash(command -v gh-watch)
---

Argument : `$ARGUMENTS` (vide : le dépôt courant, tous hors d'un clone GitHub ;
`owner/repo` : ce dépôt ; `--all` : tous ; `--full` avec `--all` : tout le détail ;
`--auto` : les PR dont un watcher gère l'état, avec leur suivi ; `--missed` : celles dont
il a manqué l'action).

Lecture seule : rien n'est lancé, posté ni modifié. **Court** : la réponse tient sur un
écran, sans commentaire en plus des tableaux.

`gh-watch` absent du `PATH` (`command -v gh-watch`) : dire qu'il s'installe avec le plugin
(`./install.sh plugin gh-watch` depuis claude-tools, ou avec `review` / `git-tidy` qui en
dépendent) et s'arrêter.

1. `gh-watch board <argument> --json`. En erreur : afficher le message tel quel et
   s'arrêter. `fallback` vrai : le signaler en une ligne (hors d'un clone GitHub : tous
   les dépôts). `prs` vide : « aucune PR ouverte qui te concerne » (préciser le dépôt) et
   s'arrêter.
2. Colonnes d'une ligne, dans l'ordre des `prs` (déjà triées) :
   - **PR** : `[#n](url)` ;
   - **État** : `short`, suivi des `alerts` en clair (`ci` « CI ✗ », `conflict` « conflit »,
     `behind` « en retard ») ;
   - **Âge** : `age_days` arrondi (« 40 min », « 5 h », « 3 j »), suivi de ⚠ si `stale` ;
   - **Action** : `action.command` en code, sinon `action.text`, sinon vide ;
   - **Titre** : `title` sans le gitmoji de tête, coupé à 50 caractères.
3. Un dépôt (`repo` non nul) : titre `dépôt`, puis un tableau **À toi** (`bucket` = `me`)
   et un tableau **En attente des autres** (`others`), un tableau vide n'apparaît pas ;
   puis le reste (`rest`) en une ligne, groupé par `short` (« brouillon #199 (conflit),
   #204 · mentionné #168 »).
4. Tous (`repo` nul) : seulement ce sur quoi j'ai à agir — `bucket` = `me`, ou `state` =
   `mentioned` — en un seul tableau avec une colonne **Dépôt** en tête (dépôts avec le
   plus de lignes à moi d'abord) ; puis une ligne : « + N autres PR (en attente des
   autres, brouillons) : `/gh-watch:board --all --full` pour tout ». Avec `--full` : comme
   un dépôt, pour chaque dépôt.
5. Rien à moi : le dire en une ligne (avec `filtered` vrai : « dépôts filtrés :
   `gh-watch set board` »).
6. `--auto` ou `--missed` (les `prs` ne contiennent alors que les lignes suivies) : un
   tableau, avec une colonne **Dépôt** si `repo` est nul — **PR**, **État**, **Âge** comme
   ci-dessus, **Mode** (`watch.mode`), **Suivi** (`watch.follow`, précédé de « manquée : »
   si `watch.missed`), **Commande** (`watch.command` en code : lancer si manquée, reprendre
   si prête), **Titre**. Vide : « aucune action manquée » (`--missed`) ou « aucune PR
   suivie par un watcher en auto ou notify » (`--auto`). Avec `--missed`, finir par une
   ligne : les commandes se lancent depuis un terminal ; rien n'est lancé ici.
