---
name: diff
description: Relire son propre travail avant commit ou PR (commits de la branche depuis sa base + modifications non commitées) avec l'agent reviewer — code ajouté seulement, points priorisés et validés, puis corrections appliquées sans commit
argument-hint: "[base] [--refacto \"<piste>\"]"
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh pr view:*), Bash(gh repo view:*), Bash(gh issue view:*), mcp__claude_ai_Atlassian_Rovo__getJiraIssue, Agent, Skill
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
- La criticité (*La criticité* de `pr-expectations.md`) : déjà donnée si la PR de la
  branche (`gh pr view --json body,comments`), un message de commit ou le ticket donne un
  niveau de risque ou de criticité ; sinon noter si un skill de la session évalue le
  risque d'une PR (proposé à l'étape 5).
- Les normes : lire `${CLAUDE_SKILL_DIR}/../../pr-expectations.md` et rassembler les normes en
  vigueur et les niveaux d'exigence (*Rassembler les normes* ; base = la base retenue
  ci-dessus).

## 2. La revue

Lancer l'agent `review:reviewer` (outil Agent) avec : la plage, « working tree inclus »,
les fichiers non suivis à lire en entier, la piste `--refacto` s'il y en a une, le
ticket s'il y en a un, les blocs « Normes » et « Exigences », et la PR de la branche s'il y en a une (numéro,
titre, brouillon ou non). Il rend du JSON.

Puis **vérifier chaque constat** contre le code (lire la ligne et son contexte) : écarter
les faux positifs, ceux qui ne portent pas sur une ligne ajoutée ou modifiée (hors
renommage du cas D, voir l'agent), et au-delà de 3 refactorings. Écart au ticket donné
comme non justifié : vérifier qu'aucune justification n'existe vraiment (description de
la PR, commentaires du ticket, commits). Dire combien ont été écartés et pourquoi, en une
ligne. Écart de `messages` : vérifier la norme citée et que le commit n'est pas un
`fixup!`/`squash!`/`amend!`. Conseil qui ne suit pas le niveau d'exigence de son critère
(*Le niveau d'exigence*) : le corriger.

## 3. La validation

Lire `${CLAUDE_SKILL_DIR}/../../validation.md` et le suivre. En tête, avant la liste :
la criticité (donnée, avec sa source, ou celle de l'agent : niveau, zones, retour arrière,
ce qui manque pour un contexte manquant), les exigences appliquées (critères `élevé` et
`faible`, chacun déclaré ou déduit avec sa source ; « tous normal » sinon), le résumé de
l'agent, la couverture du ticket et ses écarts justifiés (pour information,
avec la source), et la proposition de découpage s'il y en a une (point `🔎`). Chaque écart
non justifié est un point `🔎` : écart voulu → justification à écrire, sinon → code à
corriger (faire ce qui manque, retirer l'ajout, revenir à la demande). Chaque écart de
`messages` est un point (`commit <sha>` ou `PR` à la place de `fichier:ligne`), avec le
message ou le texte corrigé.
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
- Écart de `messages` : montrer le message corrigé et proposer `/git-tidy:commits` pour
  reformuler le commit ; pour la PR, le titre ou la description corrigés à reporter. Ne
  rien réécrire ni poster soi-même.
- Niveaux d'exigence déduits : proposer le texte à ajouter à la section d'exigences du
  dépôt (ou de la créer), sans l'écrire sans accord.
- Fin : liste des fichiers modifiés et des points écartés, puis rappeler de relire le
  diff (`git diff`).

## 5. La criticité

Une fois les retours traités, si rien ne donnait la criticité (étape 1), quel que soit
son niveau : demander (`AskUserQuestion`, header « Criticité ») s'il faut évaluer le
risque de la PR maintenant — **Évaluer (Recommandé)** / **Plus tard**. Sur accord :

- un skill de la session évalue le risque d'une PR → le lancer (sur la PR de la branche
  s'il en faut une ; s'il publie sur la PR, c'est son résultat qui sert) ;
- sinon, l'évaluation du plugin : celle de l'agent (étape 2), mise à jour des
  corrections appliquées (un danger levé par une correction n'y figure plus) — proposer
  le paragraphe à mettre dans la description de la PR (« Criticité : <niveau> », zones à
  relire et ce qui peut y casser, retour arrière ; pour `haute` ou `contexte_manquant`,
  « relecture humaine conseillée » et ce qui manque), sans l'écrire.
