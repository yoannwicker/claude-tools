---
name: pr
description: Relire la PR d'un collègue avec l'agent reviewer — code ajouté seulement, points priorisés et validés — puis poster directement les commentaires gardés en une review GitHub (COMMENT)
argument-hint: "<numéro | recherche> [--refacto \"<piste>\"]"
disable-model-invocation: true
allowed-tools: Bash(gpr list:*), Bash(gpr view:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh issue view:*), Bash(gh api user:*), Bash(git:*), Bash(review-post:*), mcp__claude_ai_Atlassian_Rovo__getJiraIssue, Agent
---

Arguments : `$ARGUMENTS`

But : relire la PR de quelqu'un d'autre et lui laisser les commentaires que j'ai validés.

## 1. La PR

- Argument numérique (`83`, `#83`) → cette PR ; sinon `gpr list <recherche>` (plugin
  `git-nav`) : un seul résultat → celui-là, plusieurs → demander (`AskUserQuestion`,
  header « PR »). Sans argument : la PR en contexte dans la conversation, sinon demander.
- `gh pr view <n> --json number,title,body,url,state,author,baseRefName,headRefName,headRefOid,isDraft,commits`.
  PR fermée ou mergée → le dire et s'arrêter. PR à moi (`author` = `gh api user`) → le
  signaler et proposer `/review:diff` (sur sa branche) ou `/review:feedback`.
- Ne pas se placer sur la PR : le diff et l'API suffisent.
- `--refacto "<piste>"` : piste de refactoring à faire évaluer par l'agent.
- Le ticket : lire `${CLAUDE_SKILL_DIR}/../../ticket.md` et le suivre (`headRefName`,
  titre et description de la PR, messages de ses commits).

## 2. La revue

Lancer l'agent `review:reviewer` (outil Agent) avec : « PR #<n> », `headRefOid`, la piste
`--refacto` s'il y en a une, le ticket s'il y en a un. Il rend du JSON.

Puis **vérifier chaque constat** (lire la ligne et son contexte à `headRefOid`) : écarter
les faux positifs, ceux qui ne portent pas sur une ligne du diff (hors renommage du cas
D), et au-delà de 3 refactorings. Écart au ticket donné comme non justifié : vérifier
qu'aucune justification n'existe vraiment (description, commentaires du ticket,
commits). Dire combien ont été écartés et pourquoi, en une ligne.

## 3. La validation

Lire `${CLAUDE_SKILL_DIR}/../../validation.md` et le suivre. En tête : le résumé de
l'agent, la couverture du ticket et ses écarts justifiés (pour information, avec la
source), et la proposition de découpage s'il y en a une. Chaque écart non justifié est
un point `🔎` : demander à l'auteur de le justifier (ce qui change par rapport au ticket et
pourquoi, dans la description de la PR ou en commentaire du ticket) ou de revenir à la
demande — en commentaire sur sa ligne s'il en a une, sinon dans le corps de la review.

Pour chaque point, montrer **le commentaire tel qu'il sera posté** (pas le constat brut) : rédigé pour l'auteur, dans la
langue de la PR, court, factuel, avec la suggestion (bloc ```` ```suggestion ```` quand
c'est un remplacement exact des lignes commentées) ; préfixe selon le conseil :
`[bloquant]` (indispensable), rien (recommandé), `[nit]` (optionnel), `[question]`
(discutable ou très contestable gardé, ou point formulé en question).

Rien de retenu : le dire et s'arrêter (rien n'est posté).

## 4. La publication

Une fois la validation finie, **poster directement** (la validation vaut accord) :

- Écrire `review.json` dans le scratchpad : `{"body": "<synthèse : résumé, écarts au ticket
  gardés sans ligne, découpage proposé s'il est gardé (partie par partie : commit, PR, tâche sur l'US ou US
  séparée), remarques générales gardées>", "comments": [{"path", "line",
  "body"}…]}`.
- `review-post <n> <review.json>` (dans le `bin/` du plugin, dans le PATH) : publie une
  review `COMMENT` — jamais `APPROVE` ni `REQUEST_CHANGES`. Un commentaire dont la ligne
  n'est pas dans le diff passe dans le corps au lieu d'échouer.
- Code 3 (une review en attente à moi existe déjà) : le dire avec son lien et demander
  (`AskUserQuestion`, header « En attente ») : **La garder, ne rien poster** / **La
  supprimer et poster** (`--replace-pending`).
- Fin : l'URL de la review, le nombre de commentaires inline et passés dans le corps.
