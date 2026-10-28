---
name: diff
description: Relire son propre travail avant commit ou PR (commits de la branche depuis sa base + modifications non commitées) avec l'agent reviewer — code ajouté seulement, points priorisés et validés, puis corrections appliquées sans commit
argument-hint: "[base] [--refacto \"<piste>\"]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr view:*), Bash(gh repo view:*), Bash(gh issue view:*), mcp__claude_ai_Atlassian_Rovo__getJiraIssue, Agent
---

Arguments : `$ARGUMENTS`

But : un regard extérieur sur ce que je m'apprête à commiter ou à pousser, limité au code
ajouté ou modifié.

## 1. La cible

- Base, dans l'ordre : l'argument (hors `--refacto`) ; sinon la base de la PR de la
  branche (`gh pr view --json baseRefName`) ; sinon la branche par défaut d'`origin`
  (`git symbolic-ref refs/remotes/origin/HEAD`).
- `git merge-base <base> HEAD` → plage `<merge-base>...HEAD`, plus le working tree
  (`git diff HEAD`, et les fichiers non suivis non ignorés : `git status --porcelain`).
- Rien à relire (plage vide, working tree propre) : le dire et s'arrêter.
- `--refacto "<piste>"` : piste de refactoring à faire évaluer par l'agent.
- Le ticket : lire `${CLAUDE_SKILL_DIR}/../../ticket.md` et le suivre (branche courante,
  PR de la branche s'il y en a une, commits de la plage).

## 2. La revue

Lancer l'agent `review:reviewer` (outil Agent) avec : la plage, « working tree inclus »,
les fichiers non suivis à lire en entier, la piste `--refacto` s'il y en a une, le
ticket s'il y en a un. Il rend du JSON.

Puis **vérifier chaque constat** contre le code (lire la ligne et son contexte) : écarter
les faux positifs, ceux qui ne portent pas sur une ligne ajoutée ou modifiée (hors
renommage du cas D, voir l'agent), et au-delà de 3 refactorings. Écart au ticket donné
comme non justifié : vérifier qu'aucune justification n'existe vraiment (description de
la PR, commentaires du ticket, commits). Dire combien ont été écartés et pourquoi, en une
ligne.

## 3. La validation

Lire `${CLAUDE_SKILL_DIR}/../../validation.md` et le suivre. En tête, avant la liste :
le résumé de l'agent, la couverture du ticket et ses écarts justifiés (pour information,
avec la source), et la proposition de découpage s'il y en a une (point `🔎`). Chaque écart
non justifié est un point `🔎` : écart voulu → justification à écrire, sinon → code à
corriger (faire ce qui manque, retirer l'ajout, revenir à la demande).
Rien de retenu : le dire et s'arrêter.

## 4. L'exécution

- Points gardés : appliquer les corrections dans le working tree, **sans commit** ni
  `git add`. Une correction qui touche du code hors du diff (refactoring, renommage du
  cas D) seulement si son point a été validé un par un.
- Découpage accepté, selon la forme de chaque partie :
  - `commit` : plan de commits et `/git-tidy:commits` pour l'appliquer (ou, s'il n'y a
    pas encore de commits, l'ordre des `git add` par partie) ;
  - `pr` : les branches à créer et leur ordre de merge ;
  - `us` : la partie à sortir du diff (fichiers, hunks) ;
  - tâche sur l'US ou US séparée : montrer le brouillon à reporter dans l'outil de
    tickets (titre, description, points ouverts, US parente).

  Ne rien commiter, ne rien déplacer soi-même.
- Écart au ticket : si c'est le code, le corriger comme un autre point ; si c'est la
  justification, la rédiger (ce qui change par rapport au ticket et pourquoi) et dire où
  la mettre : description de la PR, commentaire du ticket, et/ou message du commit
  concerné (`/git-tidy:commits` s'il faut le reformuler). Ne rien poster soi-même.
- Fin : liste des fichiers modifiés et des points écartés, puis rappeler de relire le
  diff (`git diff`).
