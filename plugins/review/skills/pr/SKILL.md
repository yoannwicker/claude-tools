---
name: pr
description: Relire la PR d'un collègue — ou plusieurs PR liées ensemble (pile de PR, même sujet), avec la cohérence entre elles — avec l'agent reviewer — code ajouté seulement, points priorisés et validés — puis poster directement les commentaires gardés en une review GitHub (COMMENT) par PR, et enfin supprimer les worktrees et branches créés pour la revue s'il y en a
argument-hint: "<numéro… | recherche> [--refacto \"<piste>\"] [--prepare]"
disable-model-invocation: true
allowed-tools: Bash(gpr list:*), Bash(gpr view:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh issue view:*), Bash(gh api user:*), Bash(gh api graphql:*), Bash(gh repo view:*), Bash(git:*), Bash(review-post:*), Bash(herdr worktree list:*), mcp__claude_ai_Atlassian_Rovo__getJiraIssue, Agent, ExitWorktree
---

Arguments : `$ARGUMENTS`

But : relire la PR de quelqu'un d'autre et lui laisser les commentaires que j'ai validés.
Plusieurs PR liées (pile de PR, PR sur un même sujet, peut-être contradictoires) se
relisent ensemble : chacune pour elle-même, plus la cohérence entre elles.

**`--prepare`** (analyse en fond lancée par `review-watch`, `claude -p` : personne pour
répondre) : aucune question (`AskUserQuestion`) ni rien de posté. Étape 1 sans proposer la
pile (la citer en une ligne si elle existe), étape 2, puis le tableau de l'étape 3
(commentaires tels qu'ils seront postés, points `🔎` listés sans les trancher) ; finir par
« Prêt pour la validation » et s'arrêter. À la reprise de la session (« Reprends à la
validation »), reprendre à l'étape 3 avec ses questions, puis 4 et 5 normalement.

## 1. Les PR

- Arguments numériques (`83`, `#83`, `83 84 85`) → ces PR ; sinon `gpr list <recherche>`
  (plugin `git-nav`) : un seul résultat → celui-là, plusieurs → demander lesquelles
  (`AskUserQuestion`, `multiSelect`, header « PR »). Sans argument : la ou les PR en
  contexte dans la conversation, sinon demander.
- Pour chacune, `gh pr view <n> --json number,title,body,url,state,author,baseRefName,headRefName,headRefOid,isDraft,commits`.
  PR fermée ou mergée → le dire et la retirer du lot. PR à moi (`author` = `gh api user`)
  → le signaler et proposer `/review:diff` (sur sa branche) ou `/review:feedback` ; la
  retirer du lot. Plus aucune PR → s'arrêter. Toutes dans le dépôt courant (sinon le dire
  et s'arrêter).
- **Pile** : `gh pr list --state open --json number,title,author,baseRefName,headRefName`
  une fois ; une PR ouverte d'un autre que moi, hors du lot, dont la base est la tête d'une
  PR du lot (au-dessus) ou dont la tête est la base d'une PR du lot (en dessous), de proche
  en proche → proposer de l'ajouter (`AskUserQuestion`, `multiSelect`, header « Pile »,
  la pile listée de bas en haut). Aucune → ne rien dire.
- **Le lot** (2 PR ou plus) : chaque PR avec sa relation — `pile` (ordre de bas en haut :
  `gh pr diff` de chacune ne donne que son incrément sur la précédente) ou `sujet`
  (même sujet, bases indépendantes). L'annoncer en une ligne.
- Ne pas se placer sur les PR : le diff et l'API suffisent.
- `--refacto "<piste>"` : piste de refactoring à faire évaluer par l'agent ; dans un lot,
  pour la PR qu'elle concerne (demander si ce n'est pas clair).
- **Reprise** (PR que j'ai déjà relue : une review de moi dans `gh pr view <n> --json
  reviews`) : c'est une relecture de suivi — lancée par `review-watch` quand l'auteur a
  réagi (réponse dans un de mes fils, commentaire de la PR, fil devenu obsolète), ou
  redemandée. Relever, pour l'étape 3 :
  - **mes fils non résolus** — `gh repo view --json owner,name`, puis :

    ```
    gh api graphql -f query='query($owner: String!, $repo: String!, $n: Int!) {
      repository(owner: $owner, name: $repo) { pullRequest(number: $n) {
        reviewThreads(first: 100) { nodes { id isResolved isOutdated path line originalLine
          comments(first: 50) { nodes { author { login } body url createdAt } } } }
        comments(last: 30) { nodes { author { login } body url createdAt } } } } }' \
      -F owner=<owner> -F repo=<repo> -F n=<n>
    ```

    garder les fils `isResolved: false` dont le premier message est de moi ;
  - **les commentaires de l'auteur** sur la PR postés après ma dernière review ;
  - **le commit de ma dernière review** (`reviews[].commit.oid`) : ce qui a changé depuis.
- Le ticket : lire `${CLAUDE_SKILL_DIR}/../../ticket.md` et le suivre pour chaque PR
  (`headRefName`, titre et description de la PR, messages de ses commits) ; un ticket
  commun n'est lu qu'une fois.

## 2. La revue

Lancer l'agent `review:reviewer` (outil Agent) avec : « PR #<n> », `headRefOid`, la piste
`--refacto` s'il y en a une, le ticket s'il y en a un. Il rend du JSON. Reprise : lui
donner aussi le commit de ma dernière review (« déjà relue à <oid> : ne rapporter que ce
qui a changé depuis, et ce que je n'avais pas vu de bloquant ») et mes fils non résolus
(pour ne pas les redire).

Lot : un agent par PR (« PR #<n> du lot », plus le lot : numéro, titre, `headRefOid`,
base et relation de chaque PR) et un agent pour **le croisement** (« croisement du lot »,
le lot et les tickets de toutes), tous lancés ensemble dans un même message.

Puis **vérifier chaque constat** (lire la ligne et son contexte à `headRefOid` de sa PR) :
écarter les faux positifs, ceux qui ne portent pas sur une ligne du diff de leur PR (hors
renommage du cas D), et au-delà de 3 refactorings par PR. Constat de croisement : lire
aussi l'autre côté (`autre`) et vérifier que le conflit ou la dépendance existe vraiment ;
doublon d'un constat d'une PR → n'en garder qu'un. Écart au ticket donné comme non
justifié : vérifier qu'aucune justification n'existe vraiment (description, commentaires
du ticket, commits). Dire combien ont été écartés et pourquoi, en une ligne.

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

Lot : un seul tableau, avec une colonne `PR`, trié par PR (ordre de la pile) puis
conseil ; les constats de croisement à la fin (`#83 ↔ #84`). Leur commentaire est posté
sur la PR de leur ligne et cite l'autre côté (`#84`, `chemin:ligne`) ; le corps de la
review de l'autre PR y renvoie en une ligne.

**Reprise : mes fils**, avant les nouveaux points, un tableau d'un fil par ligne : le
fil (`chemin:ligne`, mon retour en quelques mots), ce qui s'est passé (réponse de
l'auteur résumée, code modifié — lire la ligne à `headRefOid` et dire si le retour est
traité —, ou rien), et l'action proposée : **résoudre** (traité, ou réponse qui me
convainc), **répondre** (texte tel qu'il sera posté : désaccord argumenté, précision,
« corrigé ailleurs ? »), ou **laisser** (rien de neuf). Les commentaires de l'auteur hors
fil : y répondre dans le corps de la review s'ils m'attendent. Valider fil par fil comme
les points (`validation.md`).

Rien de retenu (ni nouveau point, ni action sur mes fils) : le dire et s'arrêter (rien
n'est posté).

## 4. La publication

Une fois la validation finie, **poster directement** (la validation vaut accord), une
review par PR qui a des points gardés (lot : de bas en haut de la pile) :

- Écrire `review.json` dans le scratchpad : `{"body": "<synthèse : résumé, écarts au ticket
  gardés sans ligne, découpage proposé s'il est gardé (partie par partie : commit, PR, tâche sur l'US ou US
  séparée), remarques générales gardées ; lot : « Relue avec #84 (pile / même sujet) » et
  les points de croisement sans ligne>", "comments": [{"path", "line", "body"}…]}`
  (lot : `review-<n>.json`).
- `review-post <n> <review.json>` (dans le `bin/` du plugin, dans le PATH) : publie une
  review `COMMENT` — jamais `APPROVE` ni `REQUEST_CHANGES`. Un commentaire dont la ligne
  n'est pas dans le diff passe dans le corps au lieu d'échouer.
- Code 3 (une review en attente à moi existe déjà) : le dire avec son lien et demander
  (`AskUserQuestion`, header « En attente ») : **La garder, ne rien poster** / **La
  supprimer et poster** (`--replace-pending`).
- Reprise, mes fils validés : après la review (ou sans review s'il n'y a pas de nouveau
  point), pour chaque fil **répondre** :

  ```
  gh api graphql -f query='mutation($id: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId: $id, body: $body }) { comment { url } } }' \
    -F id=<thread id> -f body=<texte>
  ```

  et pour chaque fil **résoudre** (je suis le relecteur : c'est à moi de le faire) :
  `gh api graphql -f query='mutation($id: ID!) { resolveReviewThread(input: { threadId: $id }) { thread { isResolved } } }' -F id=<thread id>`.
- Fin : l'URL de chaque review, le nombre de commentaires inline et passés dans le corps ;
  reprise : les fils répondus et résolus.

## 5. Le ménage (seulement si un worktree ou une branche a été créé pour la revue)

Toujours la dernière étape, même si rien n'a été posté. Lot : pour chaque PR (son `<n>`,
`headRefOid`, `headRefName`), avec une seule question pour l'ensemble. Quel que soit l'outil qui les a
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
