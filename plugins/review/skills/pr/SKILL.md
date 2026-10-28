---
name: pr
description: Relire la PR d'un collègue avec l'agent reviewer — code ajouté seulement, points priorisés et validés — puis poster directement les commentaires gardés en une review GitHub (COMMENT), et enfin supprimer le worktree et la branche créés pour la revue s'il y en a
argument-hint: "<numéro | recherche> [--refacto \"<piste>\"]"
disable-model-invocation: true
allowed-tools: Bash(gpr list:*), Bash(gpr view:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh issue view:*), Bash(gh api user:*), Bash(git:*), Bash(review-post:*), Bash(herdr worktree list:*), mcp__claude_ai_Atlassian_Rovo__getJiraIssue, Agent, ExitWorktree
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

## 5. Le ménage (seulement si un worktree ou une branche a été créé pour la revue)

Toujours la dernière étape, même si rien n'a été posté. Quel que soit l'outil qui les a
créés (Herdr UI, `/git-nav:pr`, `gh pr checkout`, à la main…), un worktree et sa branche
ont pu être ouverts pour relire la PR et n'ont plus d'usage ensuite. La branche part avec
le worktree, et seule si son worktree a déjà disparu (Herdr retire ses worktrees sans
supprimer leur branche).

1. **Les trouver** :
   - worktrees : `git worktree list --porcelain`, en gardant les worktrees liés (pas le
     dépôt principal) dont HEAD est `headRefOid` ou la branche `headRefName` — celui de
     la session en premier (`git rev-parse --git-dir` ≠ `--git-common-dir`) ;
   - branches locales de cette PR sans worktree : au nom de revue
     (`git branch --list 'agent/review-<n>-*' 'review/*<n>*' 'pr-<n>'` : celles de
     `%(worktreepath)` vide), ou `headRefName` créée au cours de cette conversation.

   Créé pour la revue : ouvert au cours de cette conversation, ou branche au nom de revue
   (`agent/review-<n>-…` de Herdr UI, `review/…`, `pr-<n>`…). Dans le doute, demander.
   Aucun : rien à faire, ne rien dire.
2. **Rien à perdre** : worktree propre (`git -C <chemin> status --porcelain` vide), et
   commit de chaque branche sur `origin` (`git branch -r --contains <branche ou HEAD>` non
   vide, ou = `headRefOid`). Sinon : dire ce qui bloque et ne pas y toucher.
3. Demander (`AskUserQuestion`, header « Ménage ») : **Supprimer le worktree et sa branche
   (Recommandé)** / **Les garder** — en listant ce qui sera supprimé.
4. **Supprimer** (`<dépôt>` = dépôt principal, dossier parent de
   `git rev-parse --git-common-dir`) ; une branche seulement si plus aucun worktree ne
   l'utilise, jamais celle du dépôt principal :
   - session dans le worktree : en sortir d'abord (`ExitWorktree` avec `action: "keep"`,
     jamais `remove` ; si aucune session worktree n'est active, `cd <dépôt>`) ;
   - `git -C <dépôt> worktree remove <chemin>` (jamais `--force`),
     `git -C <dépôt> worktree prune`, puis `git -C <dépôt> branch -D <branche>` pour la
     branche du worktree et celles trouvées sans worktree (sans risque, vérifié en 2) ;
   - cas particulier, worktree ouvert dans Herdr (`herdr worktree list` : ce chemin a un
     `open_workspace_id`) : le retirer par Herdr, qui ferme aussi son workspace mais garde
     la branche. Branches sans worktree d'abord (`git branch -D`). Si la session tourne
     dans ce worktree, elle se ferme avec : afficher d'abord le récapitulatif final, puis
     lancer en dernier, détaché :
     `setsid -f sh -c 'herdr worktree remove --workspace <id> && git -C <dépôt> branch -D <branche>' >>"$HOME/.cache/claude-tools/review-cleanup.log" 2>&1`
     (créer le dossier du log avant ; un échec y est écrit).

   Dire ce qui a été supprimé et où est la session.
