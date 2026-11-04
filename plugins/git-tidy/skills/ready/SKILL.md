---
name: ready
description: Préparer une PR pour le merge — remettre ses commits au propre (/git-tidy:commits), puis la rebaser sur sa base et mettre sa description et son ticket en phase (/git-tidy:pr-sync), les deux obligatoirement et dans cet ordre, puis demander la relecture si elle manque (relecteurs du dépôt classés par l'historique), ou, PR approuvée, passer le ticket JIRA en validation et rédiger le message Slack pour le testeur — toujours après accord
argument-hint: "[numéro de PR] [--prepare]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh issue view:*), Bash(gh repo view:*), mcp__claude_ai_Atlassian_Rovo__getTransitionsForJiraIssue, mcp__claude_ai_Atlassian_Rovo__getAccessibleAtlassianResources, mcp__claude_ai_Atlassian_Rovo__getJiraIssue, mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian_MCP__getAccessibleAtlassianResources, mcp__claude_ai_Atlassian_MCP__getJiraIssue, mcp__claude_ai_Atlassian_MCP__searchJiraIssuesUsingJql
---

Argument : `$ARGUMENTS`

But : enchaîner `/git-tidy:commits` puis `/git-tidy:pr-sync` sur une PR, sans pouvoir
sauter l'un des deux. On prépare le **merge** : l'historique doit sortir dans sa forme
finale (aucun `fixup!` ni commit de correction restant), même si le dépôt déconseille
le push forcé pendant la revue — c'est justement le moment de le faire. Ces skills ne
peuvent pas être lancés par l'outil Skill (`disable-model-invocation`) : lire leur
`SKILL.md` et en suivre les étapes.

**`--prepare`** (analyse en fond lancée par `tidy-watch` quand la PR a ses approbations,
`claude -p` : personne pour répondre) : aucune question (`AskUserQuestion`), rien de
réécrit, rebasé, poussé ni publié, aucun changement de branche ni worktree créé (la
session est lancée là où la branche est extraite : sinon le dire et s'arrêter). Préparer :
- étape 1 sans question ;
- `commits`, étapes 1 à 3 : sans le `git rebase origin/<branche>` (dire seulement si la
  branche est en retard sur `origin`), et le plan avant/après sans la question
  (« historique déjà propre » le cas échéant) ;
- `pr-sync` : à l'étape 2, la situation (retard sur la base, pile et PR décalées,
  conflits prévisibles) sans rebaser ;
  étapes 3 à 5, les brouillons de PR et de ticket sans la question ;
- étape 4 : la situation et les relecteurs proposés, sans la question ;
- étape 5 : les tickets à passer en validation et le message Slack, sans rien changer ;
- finir par « Prêt pour la validation » et s'arrêter.

À la reprise de la session (« Reprends à la validation »), reprendre à la question de
l'étape 3 de `commits` (ou, historique déjà propre, à l'étape 2 de `pr-sync`), puis la
suite normalement, en reprenant ce qui a été préparé sans refaire l'analyse.

## 1. La PR

- Arguments : au plus un numéro de PR et `--prepare` (voir plus haut).
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

## 3. Rebase, PR et ticket

Lire `${CLAUDE_SKILL_DIR}/../pr-sync/SKILL.md` et en suivre les étapes, avec le numéro de
la PR de l'étape 1 pour argument (son étape 1 est déjà faite : reprendre le `gh pr view`
complet qu'elle demande). Son étape 2 propose le rebase (sur la base, une autre branche,
ou toute la pile), après la réécriture : réécriture poussée → le rebase peut l'être aussi ;
réécriture gardée en local (**Plus tard**) → rebase local seulement.

Sans PR (création acceptée à l'étape 1) : ne pas redemander. Si la branche n'est pas
poussée, proposer `git push -u origin <branche>` (refus → s'arrêter : `gh pr create` en a
besoin). Puis rédiger titre et description comme le demande `pr-sync`, les montrer, créer
la PR (`gh pr create --draft --base <base> --title <titre> --body-file <fichier>`) et
reprendre `pr-sync` sur cette PR à partir de son étape 2 (rebase).

## 4. Relecture

Après `pr-sync` (même s'il n'a rien publié), sauf PR fermée ou mergée :
`gh pr view <n> --json isDraft,author,reviewRequests,latestReviews,reviewDecision`.

**Réglages du dépôt** (`<réglages>`) : `~/.config/claude-tools/git-tidy.json` (partagé avec
`tidy-watch`), `{"default": {…}, "repos": {"<owner/repo>": {…}}}` (dépôt en minuscules ;
une clé du dépôt l'emporte sur `default`) — `approvals` (approbations attendues, `<N>`, 2
par défaut), `reviewers` (liste de relecteurs), `validation_status` (statut
JIRA de l'étape 5, `En validation` par défaut), `test_env` (environnement de test de
l'étape 5). Fichier absent : rien de réglé.

**Situation**, d'après le dernier avis de chaque relecteur (`latestReviews`, hors l'auteur) :
- au moins `<N>` approbations toujours valides (`APPROVED`) → rien à demander : le dire en
  une ligne et passer à l'étape 5 (passage en validation) ;
- des approbations écartées par le push (`DISMISSED`, ou approbation antérieure au push
  avec `reviewDecision` revenu à `REVIEW_REQUIRED`) → **re-demander à ceux qui avaient
  approuvé**, en premier ;
- brouillon, ou moins de `<N>` relecteurs (demandes en attente dans `reviewRequests` et
  avis déjà donnés comptés) → **compléter jusqu'à `<N>`**.

**Candidats** (jamais l'auteur, moi, ni un bot ; ceux déjà demandés sont gardés tels quels) :
1. **Liste du dépôt** : `reviewers` des `<réglages>` (`["login", "org/équipe", …]`). Une
   équipe (`org/équipe`) se demande telle quelle, sans classement.
2. **Historique** : `gh pr list --state merged -L 30 --json number,author,reviews,files`.
   Pour chaque personne : nombre de PR relues, et PR relues ou écrites qui touchent les
   mêmes fichiers ou dossiers que cette PR (`files` de `gh pr view`). Classer par
   connaissance des fichiers touchés, puis par nombre de relectures.
3. Avec une liste : ne proposer que ses membres, classés par l'historique (un membre sans
   historique en dernier). Sans liste : les mieux classés de l'historique.

Montrer la proposition : les `<N>` premiers retenus, chacun avec sa raison en une ligne (ex.
« 6 des 30 dernières PR relues, a relu `src/api/` »), puis 2 ou 3 autres candidats.
`AskUserQuestion` (header « Relecture ») :
- **Demander à <retenus> (Recommandé)** ;
- **Choisir** : une option par candidat (`multiSelect`), « Autre » pour un login ou une
  équipe en texte libre ;
- **Plus tard** → étape 6.

Puis, si la PR est en brouillon : `gh pr ready <n>` (le dire), et
`gh pr edit <n> --add-reviewer <login,org/équipe,…>`. Échec (login inconnu, pas
collaborateur) : le dire, sans réessayer d'autres noms.

Sans liste pour ce dépôt, proposer de retenir les relecteurs choisis comme liste
(`AskUserQuestion`, header « Liste » : **Retenir pour <owner/repo>** / **Non**) ; accord →
écrire `repos.<owner/repo>.reviewers` dans `git-tidy.json` en gardant le reste du fichier.
Pour la modifier ensuite : éditer ce fichier.

## 5. Passage en validation

Seulement si la PR a ses `<N>` approbations valides à la fin de l'étape 4 (sinon passer à
l'étape 6). Pile de PR (repérée par `pr-sync`, étape 2) : prendre toute la pile, et pour
chaque PR ses approbations (même règle).

**Tickets** : la clé JIRA de chaque PR, cherchée comme à l'étape 4 de `pr-sync` (déjà
trouvée pour cette PR ; pour les autres PR de la pile : nom de branche, titre,
description). Pour chaque ticket : `getJiraIssue` (résumé, statut, description) et ses
PR. Pas de ticket JIRA (issue GitHub, rien) : pas de passage de statut, le message reste
possible.

**Statut** (`<statut>`) : `validation_status` des `<réglages>`, sinon `En validation`.

**Environnement de test** (`<env>`), dans l'ordre :
1. `test_env` des `<réglages>` (texte ou URL ; `{pr}`, `{branch}` et `{ticket}` y sont
   remplacés) ;
2. sinon les déploiements GitHub de la branche :
   `gh api repos/<owner/repo>/deployments?ref=<headRefName>&per_page=5`, puis pour le plus
   récent `gh api repos/<owner/repo>/deployments/<id>/statuses?per_page=1` →
   `environment_url` (sinon le nom de l'environnement) ;
3. sinon le demander dans la question ci-dessous (« Autre »), et proposer de le retenir
   (`test_env` du dépôt).

**Ticket en validation**, par ticket :
- déjà au statut `<statut>` → rien (le dire) ;
- une PR du ticket sans ses approbations → ne pas le passer, dire laquelle manque ;
- sinon : transitions possibles (`getTransitionsForJiraIssue` ; MCP `claude.ai Atlassian
  MCP` : l'opération équivalente par `discover`), celle qui mène à `<statut>` (nom de la
  transition ou statut d'arrivée, sans tenir compte de la casse). Aucune : le dire avec
  le statut actuel et les transitions possibles, ne rien forcer.

**Message Slack**, en français, à copier tel quel (dans un bloc de code ; texte simple et
URL en clair, que Slack rend cliquables ; `*gras*` seulement pour les titres) :

```
*Ticket* (ou *Tickets* s'il y en a plusieurs)
• <KEY> — <description succincte : ce que le ticket apporte, en une ligne> — <URL JIRA>
*PRs* (seulement pour une pile)
• <KEY> : <URL PR>, <URL PR>   (PR rangées sous leur ticket ; sans ticket : URL seule)
*Env de test* : <env>
```

Rien d'autre : pas de détails de PR, pas de liste de commits. Une seule PR : pas de section
*PRs* (l'URL de la PR seulement si aucun ticket n'est lié).

Montrer les tickets à passer (`<KEY>` : statut actuel → `<statut>`) et le message, puis
`AskUserQuestion` (header « Validation ») :
- **Passer en « <statut> » et garder le message (Recommandé)** — pas proposé s'il n'y a
  aucun ticket à passer ;
- **Message seulement** ;
- **Ajuster** (l'utilisateur dit quoi : statut, environnement, texte ; on repropose) ;
- **Plus tard** → étape 6.

Accord → `transitionJiraIssue` pour chaque ticket (un échec n'arrête pas les autres : le
dire). Puis redonner le message final dans un bloc de code, prêt à copier ; si
`wl-copy` ou `xclip` existe, proposer de le mettre dans le presse-papiers.

## 6. Fin

Résumer : commits réécrits ou non, rebase fait ou non (et les sauvegardes `backup/…`), push
fait ou non, relecture demandée ou non (à qui), tickets passés en validation, liens de ce qui
a été publié (PR, ticket), et le message Slack s'il a été rédigé.
