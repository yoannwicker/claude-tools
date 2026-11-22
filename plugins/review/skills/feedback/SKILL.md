---
name: feedback
description: Traiter les retours reçus sur sa PR — chaque fil de review non résolu analysé, priorisé avec un conseil, avec une solution, des options ou « à discuter » — puis, après validation, corrections en commits fixup, réponses sur les fils (avec leur statut : corrigé, justifié, reporté), push sur accord et résolution des fils traités, relance des relecteurs qui n'ont pas validé une fois tous les fils traités, et compte rendu lisible de ce qui a été demandé et traité
argument-hint: "[numéro de PR] [--prepare]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr view:*), Bash(gh pr edit:*), Bash(gh repo view:*), Bash(gh api user:*), Bash(gh api graphql:*)
---

Argument : `$ARGUMENTS`

But : ne laisser aucun retour sans suite, en décidant vite de ce qui est simple et en
prenant le temps sur ce qui le mérite : chaque fil est analysé et une suite est proposée.

**`--prepare`** (préparation lancée par `review-watch`, en fond avec `claude -p` ou
dans herdr avec `launch --background` : personne pour répondre) : aucune question
(`AskUserQuestion`), aucune correction, aucun commit ni réponse.
Étapes 1 à 3, puis le tableau de l'étape 4 (suite et réponse prévue de chaque fil, options et
« à discuter » listés sans les trancher) ; finir par « Prêt pour la validation » et
s'arrêter. À la reprise de la session (« Reprends à la validation »), reprendre à l'étape 4
avec ses questions, puis 5 normalement.

## 1. La PR

- Argument numérique → cette PR ; sinon celle de la branche courante (`gh pr view`) ;
  sinon demander (`AskUserQuestion`, header « PR »).
- `gh pr view <n> --json id,number,url,state,author,headRefName,baseRefName`. PR fermée ou
  mergée → s'arrêter. PR qui n'est pas à moi → le signaler et proposer `/review:pr`.
- Branche de la PR qui n'est pas la branche courante → l'analyse peut se faire, mais pas
  les corrections : le dire d'emblée et proposer `/git-nav:pr <n>` pour s'y placer.
- Modifications non commitées : le signaler (les fixups ne prendront que les fichiers
  corrigés).

## 2. Les fils non résolus et les suivis

`gh repo view --json owner,name`, puis :

```
gh api graphql -f query='query($owner: String!, $repo: String!, $n: Int!) {
  repository(owner: $owner, name: $repo) { pullRequest(number: $n) {
    reviewThreads(first: 100) { nodes { id isResolved isOutdated path line originalLine
      comments(first: 50) { nodes { author { login } body url diffHunk createdAt } } } }
    suivi: comments(first: 100) { nodes { author { login } body url } } } } }' \
  -F owner=<owner> -F repo=<repo> -F n=<n>
```

Garder les fils `isResolved: false`. Un fil dont j'ai le dernier mot est gardé mais
marqué `↩ répondu` (souvent en attente du relecteur).

**Les suivis** (*Le suivi des points* de `pr-expectations.md`) : dans `suivi`, les
commentaires qui commencent par `<!-- review:suivi -->`, écrits par un autre que moi (un
par relecteur). Chaque fil y reprend son conseil (bloquant, recommandé…) ; les points
**sans fil** (écart dans le corps de la review) encore ouverts ou en discussion sont
traités comme des fils (réponse dans un commentaire de la PR, étape 5.3).

Aucun fil non résolu ni point de suivi ouvert → le dire et s'arrêter.

## 3. L'analyse

Lire `${CLAUDE_SKILL_DIR}/../../pr-expectations.md` et rassembler les normes en vigueur
et les niveaux d'exigence (*Rassembler les normes*, à la version de `baseRefName`) ; le tri et les corrections
suivent *Dans `/review:feedback`*.

Pour chaque fil : lire toute la conversation et le code concerné (version actuelle ;
`isOutdated` → vérifier si le point tient encore). Puis lui donner :

- un **conseil** (voir `${CLAUDE_SKILL_DIR}/../../validation.md`) : indispensable si le
  relecteur a raison sur un bug, une faille, une norme en vigueur ou une des *PR expectations*
  (la citer dans la réponse) ; discutable si elle se défend mais que l'actuel aussi, ou si
  c'est du goût sans conséquence concrète ; très contestable si la demande va contre une
  norme du dépôt ou une décision documentée (la réponse cite la norme plutôt qu'un avis) ;
  un retour sur le contenu des commits ou de la PR (message, titre, description) est
  `recommandé` au plus, même marqué `[bloquant]` par le relecteur (*Messages non
  bloquants* de `pr-expectations.md`) ;
- une **suite**, selon le cas :
  - **solution** : le correctif précis (fichier, changement), quand il n'y a qu'une
    bonne réponse ;
  - **options** : 2 ou 3 façons de faire, compromis de chacune, recommandation ;
  - **à discuter** : quand le point demande une attention particulière (arbitrage
    métier, désaccord avec le relecteur, impact large, information manquante) — avec
    ce qui fait hésiter et une proposition de réponse ;
  - **déjà fait / obsolète** : le code actuel règle déjà le point → réponse qui le dit
    (commit à l'appui).
- le **texte de réponse** prévu sur le fil (dans la langue du fil, court : ce qui a été
  fait et où, ou l'argument si on ne fait pas), qui commence par le **statut** annoncé
  au relecteur : « ✅ Corrigé dans `<sha>` » (le commit poussé, connu à l'étape 5),
  « 💬 » + la justification pour garder l'actuel, « 📌 Reporté : <lien> ». Reporter
  exige le lien d'un ticket ou d'une issue : sans lien, proposer le brouillon du ticket
  (titre, description, PR d'origine) et demander le lien à la validation ; sans lien, le
  point n'est pas reporté (ne rien faire maintenant, ou une autre suite).

Options et « à discuter » sont `🔎` (validés un par un).

## 4. La validation

Suivre `${CLAUDE_SKILL_DIR}/../../validation.md`. Pour chaque fil, ce qui sera fait :
corriger (solution ou option choisie) et répondre, répondre seulement (contester,
expliquer, déjà fait), ou ne rien faire maintenant ; et si le fil sera **résolu** (voir
5.3). Ensuite une question
(`AskUserQuestion`, header « Envoi ») : **Corriger, répondre et pousser (Recommandé)** /
**Corriger et répondre, sans pousser** / **Corriger seulement, rien sur GitHub**. La
description de la première dit si les relecteurs seront relancés ensuite (étape 5.4) : tous
les fils pris en compte, avec qui sera relancé, ou ce qui l'empêche.

## 5. L'exécution

Des retours peuvent arriver pendant la session (une deuxième review après l'analyse) : rien
ne les signale (`review-watch` prévient une session déjà ouverte, mais sans garantie). Les
fils sont donc **relus** (requête de l'étape 2) au début de l'étape 5, puis juste avant la
relance (5.4). Un fil non résolu absent de l'analyse, ou un fil analysé qui a reçu un
nouveau commentaire d'un autre que moi, est **nouveau** :

- au début de l'étape 5 : ne rien exécuter, lister les nouveaux fils (auteur, date,
  fichier) et proposer (`AskUserQuestion`, header « Nouveaux ») : **Les analyser d'abord
  (Recommandé)** — étape 3 sur ces fils, puis étape 4 pour eux seuls, et exécution de
  l'ensemble — / **Exécuter ce qui est validé, puis les analyser** (pas de relance à 5.4) ;
- avant la relance : pas de relance ; les lister et proposer de reprendre l'étape 3 sur
  ces fils.

Un message de `review-watch` reçu en cours de session (« Nouveaux retours sur #n… ») fait
relire les fils tout de suite : avant l'étape 5, les nouveaux fils rejoignent l'analyse ;
pendant ou après, comme ci-dessus.

1. **Corrections** (seulement sur la branche de la PR) : appliquer les solutions et
   options retenues, selon les *PR expectations* : un bug signalé est corrigé avec un test qui le
   couvre ; une demande qui fait sortir du ticket est signalée avec la justification à
   ajouter (description de la PR ou ticket). Un commit `git commit --fixup=<sha>` par
   commit corrigé (le commit qui a introduit les lignes : `git log -L` ou `git blame` sur
   la base de la PR) ; correction qui n'en vise aucun (ajout demandé) → commit normal au
   message selon les normes de commit rassemblées. Vérifier que ça compile et que les tests touchés passent quand le
   dépôt a une commande pour ça (Gradle : via `build-brief`).
2. **Push** (si validé) : `git push` simple (les fixups s'ajoutent, pas de réécriture) ;
   proposer `/git-tidy:commits` plus tard pour les fondre avant merge.
3. **Réponses** (si validé, après le push pour pouvoir citer les commits poussés) :
   pour chaque fil, `addPullRequestReviewThreadReply` :

   ```
   gh api graphql -f query='mutation($id: ID!, $body: String!) {
     addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId: $id, body: $body }) { comment { url } } }' \
     -F id=<thread id> -f body=<texte>
   ```

   Puis **résoudre les fils traités**, chacun juste après sa réponse :

   ```
   gh api graphql -f query='mutation($id: ID!) {
     resolveReviewThread(input: { threadId: $id }) { thread { isResolved } } }' -F id=<thread id>
   ```

   Traité = la demande est satisfaite sans attendre le relecteur : **corrigé** (correction
   commitée **et poussée**), **déjà fait / obsolète**, ou **reporté** avec le lien du
   ticket. Restent ouverts, pour que le
   relecteur tranche : réponse qui conteste, explique sans changer le code, pose une
   question, ou option « à discuter » ; et tout fil quand le push n'a pas eu lieu (envoi
   *sans pousser*) ou que la réponse a échoué. Une norme du dépôt qui réserve la résolution
   au relecteur l'emporte : aucun fil résolu, le dire.

   Points de suivi sans fil : une seule réponse pour tous, en commentaire de la PR (un
   point par ligne, avec son statut) :
   `gh api graphql -f query='mutation($id: ID!, $body: String!) { addComment(input: { subjectId: $id, body: $body }) { commentEdge { node { url } } } }' -F id=<id de la PR> -f body=<texte>`.
4. **Relance des relecteurs** (automatique, sans question) : seulement si l'envoi retenu
   est *Corriger, répondre et pousser*, que push et réponses ont réussi, et que **tous** les
   fils non résolus, **relus à cet instant** (aucun nouveau fil, voir plus haut), sont pris
   en compte — corrigés ou répondus pendant cette exécution, ou déjà `↩ répondu` ; un seul fil laissé de côté (« ne rien faire maintenant », « à
   discuter » non tranché) ou un échec → pas de relance, le dire. Il en va de même des
   points de suivi sans fil : tous traités (corrigés ou répondus), sinon pas de relance.
   Relecteurs à relancer :
   `gh pr view <n> --json latestReviews,reviewRequests` → auteurs des `latestReviews` dont
   l'état n'est pas `APPROVED` (`CHANGES_REQUESTED`, `COMMENTED`, `DISMISSED`), hors moi,
   hors bots (`[bot]`) et hors ceux déjà dans `reviewRequests` (relance déjà en attente).
   Puis `gh pr edit <n> --add-reviewer <login1>,<login2>` (redemande la review, ce qui les
   notifie). Personne à relancer → le dire.
5. **Compte rendu** : un tableau, une ligne par **sujet** (fils qui portent sur la même
   chose regroupés), lisible par un humain :

   | Sujet | Conseil | Statut | Comment |
   |---|---|---|---|
   | Null non géré dans `api.ts` | bloquant | ✅ corrigé | garde ajoutée + test (`e4f5a6b`) |
   | Index manquant | recommandé | 📌 reporté | [#312](<lien>) |
   | Renommer `tmp` | optionnel | ❌ rejeté | nom imposé par l'API externe |
   | Cache invalide ? | question | 💬 répondu | invalidé au push (fil laissé ouvert) |

   Statuts : ✅ corrigé, ✔️ déjà fait, 📌 reporté (lien du ticket ou de l'issue),
   💬 répondu (explication, précision), ❌ rejeté (on garde l'actuel, argument donné),
   ⏸️ laissé de côté (rien fait maintenant), 🆕 nouveau (arrivé en cours de session, non
   traité) ; « fil résolu » ou « laissé ouvert » dans la colonne *Comment*. Puis, en une
   ligne chacun : les liens des réponses, et les relecteurs relancés ou pourquoi aucune
   relance.
