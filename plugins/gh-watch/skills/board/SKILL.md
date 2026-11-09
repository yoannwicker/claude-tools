---
name: board
description: Faire le point sur les PR ouvertes qui me concernent — sur le dépôt courant, un dépôt donné ou tous (--all : seulement ce sur quoi j'ai à agir, dépôts filtrés par gh-watch set board) — ce qui est à moi (retours à traiter, approuvée à préparer, à faire relire, relecture demandée…), ce qui attend les autres, depuis quand, et l'action proposée pour chacune ; --auto : le suivi par les watchers (review-watch, tidy-watch) ; --missed : les actions qu'ils ont manquées, à lancer ou écarter ; -i : agir ligne par ligne (liste interactive dans un pane herdr, sinon questions)
argument-hint: "[<owner/repo> | --all] [--full | --auto | --missed [--launch]] [--skipped] [-i]"
disable-model-invocation: true
allowed-tools: Bash(gh-watch board:*), Bash(gh-watch launch:*), Bash(gh-watch skip:*), Bash(gh-watch unskip:*), Bash(command -v gh-watch), Bash(gh pr view:*), Read(~/.config/claude-tools/git-tidy.json), mcp__claude_ai_Atlassian_Rovo__getAccessibleAtlassianResources, mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian_MCP__getAccessibleAtlassianResources, mcp__claude_ai_Atlassian_MCP__searchJiraIssuesUsingJql
---

Argument : `$ARGUMENTS` (vide : le dépôt courant, tous hors d'un clone GitHub ;
`owner/repo` : ce dépôt ; `--all` : tous ; `--full` avec `--all` : tout le détail ;
`--auto` : les PR dont un watcher gère l'état, avec leur suivi ; `--missed` : celles dont
il a manqué l'action, à lancer ou écarter ; `--launch` avec `--missed` : les lancer toutes
sans demander ; `--skipped` : montrer aussi les lignes écartées ; `-i` : agir ligne par
ligne).

Lecture seule, sauf `--missed` et `-i` (étapes 0 et 8) : seul ce qui y est choisi est
lancé ou écarté. **Court** : la réponse tient sur un
écran, sans commentaire en plus des tableaux.

`gh-watch` absent du `PATH` (`command -v gh-watch`) : dire qu'il s'installe avec le plugin
(`./install.sh plugin gh-watch` depuis claude-tools, ou avec `review` / `git-tidy` qui en
dépendent) et s'arrêter.

0. `-i` dans l'argument (pas avec `--launch`) : `gh-watch board <argument>` tel quel.
   - Réussi (« liste ouverte dans un pane herdr… ») : afficher ce message en une ligne et
     s'arrêter — tout se fait dans la liste.
   - « il faut un terminal (ou herdr) » : continuer sans `-i` (étapes 1 à 7), puis
     l'étape 8 sur les lignes à agir : toutes celles de `--auto`/`--missed`, sinon
     `bucket` = `me` ou `state` = `mentioned`.
   - Autre erreur : l'afficher telle quelle et s'arrêter.
1. `gh-watch board <argument sans -i> --json`. En erreur : afficher le message tel quel et
   s'arrêter. `fallback` vrai : le signaler en une ligne (hors d'un clone GitHub : tous
   les dépôts). `prs` vide : « aucune PR ouverte qui te concerne » (préciser le dépôt) et
   s'arrêter.
2. **JIRA**, pour mes PR (`mine`) des tableaux des étapes 4 et 5 ; sauté, sans le dire,
   si le MCP Atlassian (`claude.ai Atlassian Rovo` ou `claude.ai Atlassian MCP`) manque ou
   échoue :
   - clé `[A-Z][A-Z0-9]+-\d+` dans `title`, sinon dans la branche puis la description
     (`gh pr view <n> --repo <repo> --json headRefName,body`), comme l'étape 4 de
     `/git-tidy:pr-sync` mais sans demander : la première trouvée, aucune → `—` ;
   - `getAccessibleAtlassianResources` (`cloudId`), puis **un seul**
     `searchJiraIssuesUsingJql` (`key in (…)`, `fields: ["status"]` ; lien : `webUrl`) ;
   - réglages du dépôt dans `~/.config/claude-tools/git-tidy.json` (`repos.<dépôt en
     minuscules>`, sinon `default`) : `validation_status` (`En validation` par défaut),
     `jira_ready` (statuts « validé », séparés par des virgules ; non réglé : aucun) ;
   - `approved` dont le ticket est à `validation_status` : État « en validation », sans
     action (attend le testeur).
3. Colonnes d'une ligne, dans l'ordre des `prs` (déjà triées) :
   - **PR** : `[#n](url)` ;
   - **État** : `short`, suivi des `alerts` en clair (`ci` « CI ✗ », `conflict` « conflit »,
     `behind` « en retard ») ;
   - **JIRA** (si l'étape 2 a abouti ; vide pour les PR des autres) : `[CLÉ](webUrl)`
     et le statut, suivi de ✓ s'il est dans `jira_ready` ;
   - **Âge** : `age_days` arrondi (« 40 min », « 5 h », « 3 j »), suivi de ⚠ si `stale` ;
   - **Action** : `action.command` en code, sinon `action.text`, sinon vide ;
   - **Titre** : `title` sans le gitmoji de tête, coupé à 50 caractères.
4. Un dépôt (`repo` non nul) : titre `dépôt`, puis un tableau **À toi** (`bucket` = `me`)
   et un tableau **En attente des autres** (`others`), un tableau vide n'apparaît pas ;
   puis le reste (`rest`) en une ligne, groupé par `short` (« brouillon #199 (conflit),
   #204 · mentionné #168 »).
5. Tous (`repo` nul) : seulement ce sur quoi j'ai à agir — `bucket` = `me`, ou `state` =
   `mentioned` — en un seul tableau avec une colonne **Dépôt** en tête (dépôts avec le
   plus de lignes à moi d'abord) ; puis une ligne : « + N autres PR (en attente des
   autres, brouillons) : `/gh-watch:board --all --full` pour tout ». Avec `--full` : comme
   un dépôt, pour chaque dépôt.
6. Rien à moi : le dire en une ligne (avec `filtered` vrai : « dépôts filtrés :
   `gh-watch set board` »).
7. `--auto` ou `--missed` (les `prs` ne contiennent alors que les lignes suivies) : un
   tableau, avec une colonne **Dépôt** si `repo` est nul — **PR**, **État**, **Âge** comme
   ci-dessus, **Mode** (`watch.mode`), **Suivi** (`watch.follow`, précédé de « manquée : »
   si `watch.missed`), **Commande** (`watch.command` en code : lancer si manquée, reprendre
   si prête), **Titre**. Vide : « aucune action manquée » (`--missed`) ou « aucune PR
   suivie par un watcher en auto ou notify » (`--auto`).
8. `--missed` (ou `-i` sans herdr, étape 0) avec des lignes :
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
9. `skipped` > 0 et sans `--skipped` : finir par « N écartée(s) — `/gh-watch:board
   --skipped` pour les voir, `gh-watch unskip <dépôt>#<n>` pour en réintégrer une ».
