---
name: decisions
description: Revue des décisions d'une PR ou de son propre travail — architecture, fonctionnel, écart au ticket, contrat et données, non-décisions — relevées par l'agent challenger ; seules celles qui font sujet sont présentées, avec un avis demandé point par point. PR d'un collègue : les retours validés sont postés en une review GitHub et suivis dans le commentaire de suivi de /review:pr. Son propre travail : chaque point est traité sur place (correction, ou justification ajoutée à la description de la PR dans « Choix assumés »). Aussi proposée par /review:pr et /review:diff, en même temps que leur revue
argument-hint: "[numéro | recherche]"
disable-model-invocation: true
allowed-tools: Bash(gpr list:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh issue view:*), Bash(gh api user:*), Bash(gh api graphql:*), Bash(gh repo view:*), Bash(git:*), Bash(review-post:*), mcp__claude_ai_Atlassian_Rovo__getJiraIssue, Agent, Skill
---

Arguments : `$ARGUMENTS`

But : la revue des décisions seule, sans la revue de code (`/review:pr` et
`/review:diff` la proposent aussi, avec la leur). Tout le déroulé commun est dans
`${CLAUDE_SKILL_DIR}/../../decisions.md` : le lire et le suivre.

## 1. La cible et le mode

- Numéro (`83`, `#83`) → cette PR ; texte → `gpr list <recherche>` (plugin `git-nav`),
  plusieurs résultats → demander (`AskUserQuestion`, header « PR ») ; sans argument → la
  PR de la branche courante (`gh pr view --json number`), sinon la branche courante sans
  PR.
- PR : `gh pr view <n> --json number,id,title,body,url,state,author,baseRefName,headRefName,headRefOid,isDraft,commits`.
  Fermée ou mergée → le dire et s'arrêter.
- **Mode revue** : PR d'un autre que moi (`author` ≠ `gh api user`). Ne pas se placer
  sur la PR : le diff et l'API suffisent.
- **Mode auteur** : ma PR, ou ma branche sans PR (plage `<merge-base>...HEAD` plus le
  working tree, base comme `/review:diff`). Rien à relire → le dire et s'arrêter.
- Le ticket : `${CLAUDE_SKILL_DIR}/../../ticket.md`. Les normes et les exigences :
  `${CLAUDE_SKILL_DIR}/../../pr-expectations.md`, *Rassembler les normes* (à la version
  de la base).

## 2. Les décisions

L'agent, la vérification et la présentation de `decisions.md`. En tête, le résumé de
l'agent (`resume`, 3 à 5 lignes) et la couverture du ticket. Mode revue : à la fin, le
tableau des commentaires (n°, famille, `fichier:ligne` ou « corps », commentaire) et une
validation comme dans `${CLAUDE_SKILL_DIR}/../../validation.md` (*Validation en liste*).

## 3. L'exécution

**Mode revue** — poster directement (la validation vaut accord) :

- `review.json` dans le scratchpad : `{"body": "<Revue des décisions : résumé en 2 lignes,
  points sans ligne, brouillons de tickets de suite proposés>", "comments": [{"path",
  "line", "body"}…]}` puis `review-post <n> review.json` : une review `COMMENT`, jamais
  `REQUEST_CHANGES` ni d'approbation (c'est l'affaire de `/review:pr`). Code 3 (review
  en attente à moi) : comme l'étape 4 de `${CLAUDE_SKILL_DIR}/../pr/SKILL.md`.
- Puis le **suivi** de mes points (`<!-- review:suivi -->`), comme à l'étape 4 de
  `/review:pr` : relire mon suivi (requête de son étape 1), garder ses points et y
  ajouter les nouveaux (ouverts, reliés à leur fil), le mettre à jour ou le créer.
- Rien de gardé : rien n'est posté.

**Mode auteur** : *Mode auteur : corrections et choix assumés* de `decisions.md`.

## 4. Fin

- Mode revue : l'URL de la review, le nombre de commentaires inline et dans le corps, le
  lien du suivi.
- Mode auteur : les fichiers modifiés (rappeler de relire `git diff`), les choix assumés
  ajoutés (à la PR, ou au fichier repris à la création de la PR), les brouillons de
  tickets.
