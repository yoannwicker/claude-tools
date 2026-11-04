---
name: pr-sync
description: Mettre une PR GitHub à jour — rebase proposé si elle est en retard (sur sa base, sur une autre branche, ou toute la pile de PR), puis description en phase avec ce qui a réellement changé, raccordée au ticket JIRA ou à l'issue GitHub lié — mise à jour du ticket ou commentaire si besoin, toujours après accord
argument-hint: "[numéro de PR]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh issue view:*), Bash(gh repo view:*), mcp__claude_ai_Atlassian_Rovo__getAccessibleAtlassianResources, mcp__claude_ai_Atlassian_Rovo__getJiraIssue, mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian_MCP__getAccessibleAtlassianResources, mcp__claude_ai_Atlassian_MCP__getJiraIssue, mcp__claude_ai_Atlassian_MCP__searchJiraIssuesUsingJql
---

Argument : `$ARGUMENTS`

But : que la PR parte de la base à jour, dise ce qu'elle fait vraiment, et que le ticket
qu'elle traite le sache. Rien n'est réécrit, poussé, ni écrit sur GitHub ou dans JIRA sans
accord explicite. Une commande git ou `gh` par appel Bash, sans `cd … &&` ni enchaînement.

## 1. La PR

- Choix de la PR, dans l'ordre :
  1. argument numérique → cette PR ;
  2. sinon la PR ou la branche en contexte dans la conversation (chargée par
     `/git-nav:pr` ou `/git-nav:br`, worktree ouvert, PR ou branche dont on vient de
     parler), sauf la branche par défaut du dépôt (`main`, `master`…) : sa PR
     (`gh pr view <branche>`) ;
  3. sinon la branche courante, si ce n'est pas la branche par défaut (`gh pr view`) ;
  4. sinon (plusieurs candidats, ou rien hors de la branche par défaut) : demander
     (`AskUserQuestion`, header « PR »).
- `gh pr view <n> --json number,url,title,body,state,isDraft,isCrossRepository,baseRefName,headRefName,commits,files,closingIssuesReferences`.
- Pas de PR : le dire, proposer d'en créer une en brouillon
  (`gh pr create --draft`, avec le titre et la description rédigés comme à l'étape 5) et
  s'arrêter si l'utilisateur refuse.
- PR fermée ou mergée : le dire ; on peut encore mettre à jour le ticket, pas la PR (passer
  l'étape 2).

## 2. Rebase

### Situation

- PR d'un fork (`isCrossRepository`) : dire le retard s'il y en a et passer à l'étape 3
  (pas de rebase d'ici).
- **Pile** : `gh pr list --state open --json number,title,baseRefName,headRefName,isCrossRepository`.
  Descendre de base en base (PR dont la `headRefName` est la base de la précédente)
  jusqu'à la **base racine** (branche qui n'est la tête d'aucune PR ouverte : `main`…),
  puis monter (PR dont la base est la tête de la précédente). Pile = au moins 2 PR sur
  cette chaîne, listée de bas en haut (`#81 → #84 (celle-ci) → #90`). Une PR avec
  plusieurs enfants (pile en arbre) : ne pas proposer de rebaser la pile, le dire.
- `git fetch origin <base racine>` et les têtes de la pile (sinon `<base> <headRefName>`),
  puis les retards (`<head>` : la branche locale si elle existe, sinon `origin/<tête>`) :
  - celle-ci : `git rev-list --count <head>..origin/<base>` ;
  - pile : le bas sur `origin/<base racine>`, et chaque PR au-dessus par rapport à son
    parent (`git merge-base --is-ancestor origin/<parent> origin/<enfant>` faux → enfant
    décalé : parent réécrit ou rebasé depuis).
  Rien en retard ni décalé → passer à l'étape 3 sans le dire.
- Sinon le dire (« N commits de retard sur `origin/<base>` », PR décalées de la pile) avec
  les conflits prévisibles : `git merge-tree --write-tree --name-only <head> origin/<base>`
  (code de sortie 1 → les fichiers listés après l'arbre sont en conflit ; option absente
  avant git 2.38 : ne rien prédire).
- **Branche et `origin`** (pour chaque branche à rebaser, si elle existe en local et sur
  `origin` : `git rev-list --left-right --count origin/<tête>...<branche>`) :
  - à jour, ou seulement en avance → le rebase pourra être poussé ;
  - en retard seulement (`0` à droite) → sera d'abord remise sur `origin/<tête>` (rien de
    local ne se perd) ;
  - divergée (historique local réécrit et pas encore poussé, ou quelqu'un a poussé) → le
    dire ; rebase local seulement, le push de cette branche reste à l'utilisateur.

### Choix

`AskUserQuestion` (header « Rebase ») :
- **Rebaser sur `origin/<base>` (Recommandé)** — la PR seule ;
- **Rebaser la pile** (seulement pour une pile, et alors recommandé à la place) : toutes
  les PR de bas en haut, en citant la chaîne ;
- **Rebaser sur une autre branche** ;
- **Ne pas rebaser** → étape 3 sur la branche telle qu'elle est.

**Autre branche** : demander laquelle (`AskUserQuestion`, header « Base ») : la branche par
défaut d'`origin` (`git symbolic-ref refs/remotes/origin/HEAD`) si ce n'est pas déjà la
base, les branches longues (`develop`, `release/…`, `git ls-remote --heads origin`), « Autre »
pour un nom libre (vérifié sur `origin`). La base de la PR changera aussi (étape *Pousser*).

### Rebaser

- **Dossier de travail** de chaque branche : celui où elle est extraite, choisi comme à
  l'étape 1 de `${CLAUDE_SKILL_DIR}/../commits/SKILL.md` (*Dossier de travail* et *Dossier
  occupé*) ; toute commande git s'y lance par `git -C <dossier>`. Modifications non
  commitées, ou rebase, merge, cherry-pick en cours : le dire et renoncer (pour une pile :
  à toute la pile). Branche en retard seulement sur `origin/<tête>` :
  `git rebase origin/<tête>` d'abord.
- **Sauvegarde** de chaque branche touchée : `git branch backup/<branche>-<AAAAMMJJ-HHMM> <branche>`
  (`/` du nom de branche gardés) ; noter son SHA (`<avant>`) et celui d'`origin/<tête>`.
- Selon le choix :
  - **sur la base** : `git rebase origin/<base>` ;
  - **sur une autre branche** `<cible>` : `<point>` = `git merge-base <branche> origin/<base>`
    (appel à part), puis `git rebase --onto origin/<cible> <point> <branche>` (seuls les
    commits de la PR partent : rien de l'ancienne base n'est emporté) ;
  - **la pile**, de bas en haut, une branche à la fois :
    1. le bas : `git rebase origin/<base racine>` ;
    2. chaque PR au-dessus : `git rebase --onto <parent> <ancien parent> <enfant>`, avec
       `<parent>` la branche locale du parent tout juste rebasée et `<ancien parent>` :
       son `<avant>` s'il est ancêtre de l'enfant (`git merge-base --is-ancestor`), sinon
       `git merge-base --fork-point origin/<parent> <enfant>` (parent réécrit ou rebasé
       plus tôt). Ni l'un ni l'autre : montrer `git log --oneline <parent>..<enfant>` et
       demander quels commits sont ceux de l'enfant (le premier donne `<ancien parent>`
       = son parent).
- Les commits de merge disparaissent (historique linéaire) : le signaler s'il y en avait.
- Conflit : montrer chaque fichier en conflit avec ses deux côtés et proposer une
  résolution ; l'appliquer (`git add`, `GIT_EDITOR=true git rebase --continue`) après
  accord (`AskUserQuestion`, header « Conflit » : **Appliquer** / **Ajuster** /
  **Abandonner le rebase**). Abandon → `git rebase --abort`, le dire ; pour une pile, les
  branches du dessous restent rebasées, celles du dessus ne sont pas touchées (le dire) ;
  passer à l'étape 3.
- Montrer le résultat (`git log --oneline <base>..<branche>` pour chaque branche), et
  proposer (sans l'imposer) la commande de build/test rapide du projet sur la PR (Gradle :
  passer par `build-brief`).

### Pousser

`AskUserQuestion` (header « Push ») : **Pousser** (les branches rebasées qui n'ont pas
divergé ; pile : toutes en une fois, de bas en haut) / **Plus tard**.
- `git push --force-with-lease=<branche>:<SHA d'origin/<tête> noté> origin <branche>` par
  branche (jamais `--force` seul) ; refusé → quelqu'un a poussé entre-temps : le dire, ne
  pas forcer, continuer avec les autres.
- **Autre branche** : une fois poussé, `gh pr edit <n> --base <cible>` (sans push, le
  rappeler : la PR ne doit changer de base qu'avec la branche rebasée).
- Rappeler les sauvegardes (`git reset --hard backup/…` pour revenir) et proposer de les
  supprimer une fois le résultat validé (`git branch -D`, sur accord).

## 3. Ce qui a changé

- Base à jour : `git merge-base origin/<base> <head>` (après le rebase de l'étape 2 ; `<base>` :
  la nouvelle base si elle a changé).
- `git log --reverse --format='%h %s%n%b' <merge-base>..<head>`, `git diff --stat`, puis le
  diff complet si les messages ne suffisent pas à dire ce que fait la PR. Si la branche
  n'est pas en local : `gh pr diff <n>` (après accord, il n'est pas pré-autorisé : sinon
  se contenter de `files` et des commits). Rebase local non poussé : la description porte
  sur l'historique local.
- **Format attendu** : modèle de PR du dépôt (`.github/pull_request_template.md`,
  `.github/PULL_REQUEST_TEMPLATE/`, `docs/`), consignes (`AGENTS.md`, `CLAUDE.md`,
  `CONTRIBUTING.md`), et les 5 dernières PR mergées
  (`gh pr list --state merged -L 5 --json title,body`) : langue, sections, forme du titre
  (clé de ticket, gitmoji…).

## 4. Le ticket

- Chercher la référence, dans l'ordre : `closingIssuesReferences`, puis le nom de branche,
  le titre, la description et les messages de commits — clé JIRA (`[A-Z][A-Z0-9]+-\d+`,
  ex. `ABC-123`), issue GitHub (`#123`, `Fixes #123`, URL).
- Plusieurs candidats ou aucun : demander (`AskUserQuestion`, header « Ticket »), avec
  l'option **Aucun ticket** (on ne traite alors que la PR).
- **JIRA** : outils MCP Atlassian, quel que soit le serveur (`claude.ai Atlassian Rovo` ou
  `claude.ai Atlassian MCP`, selon le profil) (`getAccessibleAtlassianResources` pour le `cloudId`,
  puis `getJiraIssue`) : résumé, description, critères d'acceptation, statut, sous-tâches,
  derniers commentaires. MCP Atlassian absent ou non authentifié : le dire, traiter la PR
  seule.
- **Issue GitHub** : `gh issue view <n> --comments`.

Comparer le ticket et la PR :
- critères couverts, partiellement couverts, non couverts ;
- ce que la PR fait en plus du ticket ;
- décisions prises dans la PR qui contredisent ou précisent le ticket (choix technique,
  périmètre réduit, comportement différent).

## 5. Rédiger

**PR** — titre et description au format du dépôt (étape 3) :
- le pourquoi (repris du ticket, en une ou deux phrases) et le lien vers le ticket (URL
  JIRA, ou `Closes #123` si la PR doit fermer l'issue) ;
- ce qui change, regroupé par thème plutôt que commit par commit ;
- ce qu'il faut regarder en relecture, les risques, la façon de tester ;
- ce qui reste hors périmètre (critères non couverts).

Garder de la description actuelle ce qu'un humain y a mis et qui reste vrai (captures,
cases cochées, contexte, mentions) ; ne réécrire que ce qui est faux ou manquant. Si elle
est déjà juste, le dire et ne rien proposer.

**Ticket** — selon l'écart trouvé à l'étape 4 :
- par défaut, un **commentaire** court : lien vers la PR, ce qu'elle livre, ce qui
  n'est pas couvert, les décisions qui s'écartent du ticket ;
- **modifier le ticket** (description, critères d'acceptation) seulement si son contenu est
  devenu faux à cause d'une décision prise dans la PR, en ne touchant qu'à la partie
  concernée ;
- rien si le ticket et la PR sont déjà raccord (lien déjà présent, rien de nouveau).
Ne jamais changer le statut, l'assigné ni le sprint sauf demande explicite.

Montrer les brouillons : titre et description de la PR (en signalant ce qui change par
rapport à l'actuelle), et le texte du commentaire ou la modification du ticket.
Puis `AskUserQuestion` (header « Publier »), une option par combinaison utile :
**PR et ticket** / **PR seulement** / **Ajuster** (l'utilisateur dit quoi, on repropose) /
**Annuler**.

## 6. Publier

- PR : `gh pr edit <n> --title <titre> --body-file <fichier>` (description écrite dans le
  scratchpad).
- JIRA : `addCommentToJiraIssue` ou `editJiraIssue` (charger leur schéma via ToolSearch si
  besoin) ; description en Markdown.
- Issue GitHub : `gh issue comment <n> --body-file <fichier>` ou
  `gh issue edit <n> --body-file <fichier>`.

Finir par le rebase (sur quoi, quelles branches, poussé ou non, sauvegardes, base changée)
et les liens de ce qui a été publié
(PR, commentaire ou ticket), et ce qui ne l'a pas été.
