---
name: board
description: Faire le point sur les PR ouvertes qui me concernent — sur le dépôt courant, un dépôt donné ou tous (--all : seulement ce sur quoi j'ai à agir, dépôts filtrés par gh-watch set board) — ce qui est à moi (retours à traiter, approuvée à préparer, à faire relire, relecture demandée…), ce qui attend les autres, depuis quand, et l'action proposée pour chacune ; --auto : le suivi par les watchers (review-watch, tidy-watch) ; --missed : les actions qu'ils ont manquées, à lancer ou écarter ; -i : agir ligne par ligne (liste interactive dans un pane herdr, sinon questions)
argument-hint: "[<owner/repo> | --all] [--full | --auto | --missed [--launch]] [--skipped] [-i]"
disable-model-invocation: true
allowed-tools: Bash(gh-watch board:*), Bash(gh-watch launch:*), Bash(gh-watch skip:*), Bash(gh-watch unskip:*), Bash(command -v gh-watch)
---

Argument : `$ARGUMENTS` (vide : le dépôt courant, tous hors d'un clone GitHub ;
`owner/repo` : ce dépôt ; `--all` : tous ; `--full` avec `--all` : tout le détail ;
`--auto` : les PR dont un watcher gère l'état, avec leur suivi ; `--missed` : celles dont
il a manqué l'action, à lancer ou écarter ; `--launch` avec `--missed` : les lancer toutes
sans demander ; `--skipped` : montrer aussi les lignes écartées ; `-i` : agir ligne par
ligne).

Lecture seule, sauf `--missed` et `-i` (étapes 0 et 7) : seul ce qui y est choisi est
lancé ou écarté. **Court** : la réponse tient sur un
écran, sans commentaire en plus des tableaux.

`gh-watch` absent du `PATH` (`command -v gh-watch`) : dire qu'il s'installe avec le plugin
(`./install.sh plugin gh-watch` depuis claude-tools, ou avec `review` / `git-tidy` qui en
dépendent) et s'arrêter.

0. `-i` dans l'argument (pas avec `--launch`) : `gh-watch board <argument>` tel quel.
   - Réussi (« liste ouverte dans un pane herdr… ») : afficher ce message en une ligne et
     s'arrêter — tout se fait dans la liste.
   - « il faut un terminal (ou herdr) » : continuer sans `-i` (étapes 1 à 6), puis
     l'étape 7 sur les lignes à agir : toutes celles de `--auto`/`--missed`, sinon
     `bucket` = `me` ou `state` = `mentioned`.
   - Autre erreur : l'afficher telle quelle et s'arrêter.
1. `gh-watch board <argument sans -i> --json`. En erreur : afficher le message tel quel et
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
   puis le reste (`rest`) en une ligne, groupé par `short` sans ses `checks` de tête, les
   coches après le numéro (« brouillon #199 (conflit), #204 ✓ · mentionné #168 »).
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
   suivie par un watcher en auto ou notify » (`--auto`).
7. `--missed` (ou `-i` sans herdr, étape 0) avec des lignes :
   - avec `--launch` : `gh-watch board <argument sans --launch> --missed --launch`, et
     montrer sa sortie ;
   - sinon `AskUserQuestion`, une question par ligne (4 par appel, appels successifs
     au-delà ; header `#n`, question : dépôt#n, état, titre, suivi) : **Lancer**
     (seulement si la ligne a un `watch` ; sinon l'action proposée en texte, à faire à
     la main) /
     **Écarter** (jusqu'au prochain événement) / **Écarter jusqu'à la fermeture** /
     **Plus tard** (rien d'enregistré : la ligne reviendra). Puis, ligne par ligne :
     `gh-watch launch <dépôt>#<n>`, `gh-watch skip <dépôt>#<n>` ou
     `gh-watch skip <dépôt>#<n> --until-closed`. Finir par une ligne par PR : lancée
     (herdr, ou analyse en fond à reprendre au clic de la notification), écartée, ou
     laissée ; un échec tel quel.
8. `skipped` > 0 et sans `--skipped` : finir par « N écartée(s) — `/gh-watch:board
   --skipped` pour les voir, `gh-watch unskip <dépôt>#<n>` pour en réintégrer une ».
