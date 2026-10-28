---
name: ready
description: Préparer une PR pour la relecture — remettre ses commits au propre (/git-tidy:commits), puis mettre sa description et son ticket en phase (/git-tidy:pr-sync), les deux obligatoirement et dans cet ordre, toujours après accord
argument-hint: "[numéro de PR]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh issue view:*), Bash(gh repo view:*), mcp__claude_ai_Atlassian_Rovo__getAccessibleAtlassianResources, mcp__claude_ai_Atlassian_Rovo__getJiraIssue, mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian_MCP__getAccessibleAtlassianResources, mcp__claude_ai_Atlassian_MCP__getJiraIssue, mcp__claude_ai_Atlassian_MCP__searchJiraIssuesUsingJql
---

Argument : `$ARGUMENTS`

But : enchaîner `/git-tidy:commits` puis `/git-tidy:pr-sync` sur une PR, sans pouvoir
sauter l'un des deux. Ces skills ne peuvent pas être lancés par l'outil Skill
(`disable-model-invocation`) : lire leur `SKILL.md` et en suivre les étapes.

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
- `gh pr view <n> --json number,url,state,baseRefName,headRefName`.
- PR fermée ou mergée : le dire et s'arrêter (proposer `/git-tidy:pr-sync` seul).
- La branche de la PR n'a pas besoin d'être la branche courante : `commits` (étape 2)
  travaille là où elle est extraite (worktree existant), sinon dans le worktree principal
  ou, s'il a du travail en cours, dans un worktree dédié.
- Branche en contexte sans PR qui n'est pas la branche courante : le dire et s'arrêter
  (proposer `/git-nav:br <branche>`).
- Pas de PR pour la branche courante : le dire et proposer d'en créer une en brouillon
  (`AskUserQuestion`, header « PR ») : **Créer en brouillon** / **Annuler**. Annuler →
  s'arrêter. Créer → continuer : la PR sera créée à l'étape 3, une fois les commits au
  propre.

## 2. Les commits

Lire `${CLAUDE_SKILL_DIR}/../commits/SKILL.md` et en suivre les étapes 1 à 6, avec
`<n> --base <baseRefName>` pour argument (sans PR : aucun argument, la base que `commits`
choisit seul), sans proposer `/git-tidy:pr-sync` à la fin.

- `commits` s'arrête (modifications non commitées, opération git en cours, aucun commit
  depuis la base, **Annuler**, retour à la sauvegarde…) : s'arrêter aussi, en le disant.
- Seul un historique déjà propre laisse continuer.
- Réécriture faite mais pas poussée (**Plus tard**) : le signaler ; la description portera
  sur l'historique local.

## 3. La PR et le ticket

Lire `${CLAUDE_SKILL_DIR}/../pr-sync/SKILL.md` et en suivre les étapes, avec le numéro de
la PR de l'étape 1 pour argument (son étape 1 est déjà faite : reprendre le `gh pr view`
complet qu'elle demande).

Sans PR (création acceptée à l'étape 1) : ne pas redemander. Si la branche n'est pas
poussée, proposer `git push -u origin <branche>` (refus → s'arrêter : `gh pr create` en a
besoin). Puis rédiger titre et description comme le demande `pr-sync`, les montrer, créer
la PR (`gh pr create --draft --base <base> --title <titre> --body-file <fichier>`) et
reprendre `pr-sync` sur cette PR à partir du ticket.

## 4. Fin

Résumer : commits réécrits ou non (et la sauvegarde `backup/…`), push fait ou non, liens
de ce qui a été publié (PR, ticket).
