---
name: pr-sync
description: Mettre la description d'une PR GitHub en phase avec ce qui a réellement changé, et la raccorder au ticket JIRA ou à l'issue GitHub lié — mise à jour du ticket ou commentaire si besoin, toujours après accord
argument-hint: "[numéro de PR]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh issue view:*), Bash(gh repo view:*), mcp__claude_ai_Atlassian_Rovo__getAccessibleAtlassianResources, mcp__claude_ai_Atlassian_Rovo__getJiraIssue, mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian_MCP__getAccessibleAtlassianResources, mcp__claude_ai_Atlassian_MCP__getJiraIssue, mcp__claude_ai_Atlassian_MCP__searchJiraIssuesUsingJql
---

Argument : `$ARGUMENTS`

But : que la PR dise ce qu'elle fait vraiment, et que le ticket qu'elle traite le sache.
Rien n'est écrit sur GitHub ni dans JIRA sans accord explicite. Une commande git ou `gh`
par appel Bash.

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
- `gh pr view <n> --json number,url,title,body,state,isDraft,baseRefName,headRefName,commits,files,closingIssuesReferences`.
- Pas de PR : le dire, proposer d'en créer une en brouillon
  (`gh pr create --draft`, avec le titre et la description rédigés comme à l'étape 4) et
  s'arrêter si l'utilisateur refuse.
- PR fermée ou mergée : le dire ; on peut encore mettre à jour le ticket, pas la PR.

## 2. Ce qui a changé

- Base à jour : `git fetch origin <base>`, puis `git merge-base origin/<base> <head>`.
- `git log --reverse --format='%h %s%n%b' <merge-base>..<head>`, `git diff --stat`, puis le
  diff complet si les messages ne suffisent pas à dire ce que fait la PR. Si la branche
  n'est pas en local : `gh pr diff <n>` (après accord, il n'est pas pré-autorisé : sinon
  se contenter de `files` et des commits).
- **Format attendu** : modèle de PR du dépôt (`.github/pull_request_template.md`,
  `.github/PULL_REQUEST_TEMPLATE/`, `docs/`), consignes (`AGENTS.md`, `CLAUDE.md`,
  `CONTRIBUTING.md`), et les 5 dernières PR mergées
  (`gh pr list --state merged -L 5 --json title,body`) : langue, sections, forme du titre
  (clé de ticket, gitmoji…).

## 3. Le ticket

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

## 4. Rédiger

**PR** — titre et description au format du dépôt (étape 2) :
- le pourquoi (repris du ticket, en une ou deux phrases) et le lien vers le ticket (URL
  JIRA, ou `Closes #123` si la PR doit fermer l'issue) ;
- ce qui change, regroupé par thème plutôt que commit par commit ;
- ce qu'il faut regarder en relecture, les risques, la façon de tester ;
- ce qui reste hors périmètre (critères non couverts).

Garder de la description actuelle ce qu'un humain y a mis et qui reste vrai (captures,
cases cochées, contexte, mentions) ; ne réécrire que ce qui est faux ou manquant. Si elle
est déjà juste, le dire et ne rien proposer.

**Ticket** — selon l'écart trouvé à l'étape 3 :
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

## 5. Publier

- PR : `gh pr edit <n> --title <titre> --body-file <fichier>` (description écrite dans le
  scratchpad).
- JIRA : `addCommentToJiraIssue` ou `editJiraIssue` (charger leur schéma via ToolSearch si
  besoin) ; description en Markdown.
- Issue GitHub : `gh issue comment <n> --body-file <fichier>` ou
  `gh issue edit <n> --body-file <fichier>`.

Finir par les liens de ce qui a été publié (PR, commentaire ou ticket), et ce qui ne l'a
pas été.
