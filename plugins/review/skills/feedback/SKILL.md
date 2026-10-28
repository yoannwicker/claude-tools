---
name: feedback
description: Traiter les retours reçus sur sa PR — chaque fil de review non résolu analysé, priorisé avec un conseil, avec une solution, des options ou « à discuter » — puis, après validation, corrections en commits fixup, réponses sur les fils et push sur accord
argument-hint: "[numéro de PR]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr view:*), Bash(gh repo view:*), Bash(gh api user:*), Bash(gh api graphql:*)
---

Argument : `$ARGUMENTS`

But : ne laisser aucun retour sans suite, en décidant vite de ce qui est simple et en
prenant le temps sur ce qui le mérite. Complément du plugin `pr-comments` (panneau fil par
fil) : ici chaque fil est analysé et une suite est proposée.

## 1. La PR

- Argument numérique → cette PR ; sinon celle de la branche courante (`gh pr view`) ;
  sinon demander (`AskUserQuestion`, header « PR »).
- `gh pr view <n> --json number,url,state,author,headRefName,baseRefName`. PR fermée ou
  mergée → s'arrêter. PR qui n'est pas à moi → le signaler et proposer `/review:pr`.
- Branche de la PR qui n'est pas la branche courante → l'analyse peut se faire, mais pas
  les corrections : le dire d'emblée et proposer `/git-nav:pr <n>` pour s'y placer.
- Modifications non commitées : le signaler (les fixups ne prendront que les fichiers
  corrigés).

## 2. Les fils non résolus

`gh repo view --json owner,name`, puis :

```
gh api graphql -f query='query($owner: String!, $repo: String!, $n: Int!) {
  repository(owner: $owner, name: $repo) { pullRequest(number: $n) {
    reviewThreads(first: 100) { nodes { id isResolved isOutdated path line originalLine
      comments(first: 50) { nodes { author { login } body url diffHunk createdAt } } } } } } }' \
  -F owner=<owner> -F repo=<repo> -F n=<n>
```

Garder les fils `isResolved: false`. Aucun → le dire et s'arrêter. Un fil dont j'ai le
dernier mot est gardé mais marqué `↩ répondu` (souvent en attente du relecteur).

## 3. L'analyse

Pour chaque fil : lire toute la conversation et le code concerné (version actuelle ;
`isOutdated` → vérifier si le point tient encore). Puis lui donner :

- un **conseil** (voir `${CLAUDE_SKILL_DIR}/../../validation.md`) : indispensable si le
  relecteur a raison sur un bug, une faille, une règle du dépôt ; discutable si elle se
  défend mais que l'actuel aussi ; très contestable si la demande est de goût ou va contre une règle ou une décision documentée ;
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
  fait et où, ou l'argument si on ne fait pas).

Options et « à discuter » sont `🔎` (validés un par un).

## 4. La validation

Suivre `${CLAUDE_SKILL_DIR}/../../validation.md`. Pour chaque fil, ce qui sera fait :
corriger (solution ou option choisie) et répondre, répondre seulement (contester,
expliquer, déjà fait), ou ne rien faire maintenant. Ensuite une question
(`AskUserQuestion`, header « Envoi ») : **Corriger, répondre et pousser (Recommandé)** /
**Corriger et répondre, sans pousser** / **Corriger seulement, rien sur GitHub**.

## 5. L'exécution

1. **Corrections** (seulement sur la branche de la PR) : appliquer les solutions et
   options retenues. Un commit `git commit --fixup=<sha>` par commit corrigé (le commit
   qui a introduit les lignes : `git log -L` ou `git blame` sur la base de la PR) ;
   correction qui n'en vise aucun (ajout demandé) → commit normal au message à la
   convention du dépôt. Vérifier que ça compile et que les tests touchés passent quand le
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

   Ne jamais résoudre un fil : c'est au relecteur (ou au plugin `pr-comments`).
4. Fin : tableau fil → suite → commit / lien de la réponse ; fils laissés de côté.
