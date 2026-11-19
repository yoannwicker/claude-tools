# Revue des décisions (commune à `/review:decisions`, `/review:pr` et `/review:diff`)

Un autre axe que la revue de code : remettre en question les **choix** que fait le diff —
architecture, fonctionnel, écart au ticket, contrat et données, non-décisions — et donner
mon avis seulement là où il y a sujet. Si tout est conforme, on le dit et c'est tout.

**Mode revue** : PR d'un autre, les points gardés deviennent des commentaires de review.
**Mode auteur** : mon propre travail, chaque point est traité sur place.

## L'agent

Lancer `review:challenger` (outil Agent) avec : la cible (« PR #<n> » et `headRefOid`, ou
la plage et « working tree inclus »), le ticket (`ticket.md`), les blocs « Normes » et
« Exigences » (`pr-expectations.md`), et les **choix déjà justifiés** : la section
« Choix assumés » de la description de la PR, et en mode auteur sans PR le fichier des
choix assumés de la branche (ci-dessous) s'il existe. Lancé depuis `/review:pr` ou
`/review:diff`, il part dans le même message que `review:reviewer`, en parallèle. Il rend
du JSON.

## La vérification

Chaque décision `sujet` : lire le code (à `headRefOid` ou dans le working tree), le
ticket, la justification. Écarter celles qui ne tiennent pas, qui sont justifiées
quelque part, ou qui sont en fait un bug ou un test manquant (déjà l'affaire de
`reviewer` : doublon d'un de ses constats → n'en garder qu'un, celui de `reviewer`). Dire
combien ont été écartées et pourquoi, en une ligne.

## La présentation

Après la validation des constats de `reviewer` (s'il y en a) :

- **Conformes** : une ligne chacune (famille, titre, pourquoi ou source), repliées dans un
  bloc `<details>` au-delà de 5.
- **Sujets** : un par un, dans l'ordre (poids, puis famille) — la famille et le titre,
  `fichier:ligne` s'il y en a un, le choix fait, ce que demande le ticket ou la norme, les
  alternatives avec leur compromis, l'enjeu et l'avis de l'agent, en quelques lignes
  (extrait de code seulement s'il éclaire). Puis une question (`AskUserQuestion`, header
  selon la famille : « Archi », « Fonctionnel », « Ticket », « Contrat », « Implicite »),
  l'option qui suit l'avis de l'agent en premier avec « (Recommandé) » :
  - mode revue : **D'accord avec le choix** (rien n'est posté) / **À challenger**
    (commentaire argumenté avec l'alternative ; « Autre » pour donner mon angle en une
    phrase) / **Question à l'auteur** (le pourquoi n'est écrit nulle part) / **Hors
    périmètre** (brouillon de ticket de suite montré à la fin, rien n'est créé) ;
  - mode auteur : **À corriger** / **Choix assumé** (pas de changement de code,
    justification à rédiger) / **Hors périmètre** (brouillon de ticket de suite, et
    justification qui y renvoie) / **D'accord, rien à dire**.

  « Autre » permet aussi d'en discuter : chercher ce qu'il faut (code, appelants,
  historique avec `git log -L` ou `git blame`, ticket), répondre, puis reposer la question.
- Aucun sujet : « Décisions : rien à remettre en question » en une ligne.

## Mode revue : les commentaires

Chaque point gardé est rédigé **tel qu'il sera posté** : pour l'auteur, dans la langue de
la PR, court et argumenté (le choix, ce qui pose question, l'alternative), préfixé par sa
famille (`[architecture]`, `[fonctionnel]`, `[ticket]`, `[contrat]`, `[implicite]`) puis,
selon le poids, `[bloquant]` (indispensable) ou `[question]` (question à l'auteur, ou
poids discutable). Il rejoint les commentaires de la review (sur sa ligne, sinon dans le
corps), avec le conseil de son poids (indispensable, recommandé, discutable) pour
l'approbation et le suivi des points (`pr-expectations.md`) : les points de décision
sont des points comme les autres.

## Mode auteur : corrections et choix assumés

- **À corriger** : dans le working tree, **sans commit** ni `git add`, comme les autres
  corrections de `/review:diff`.
- **Choix assumé** : un point par choix — `- **<titre>** (<fichier:ligne>) : <le choix> —
  <pourquoi> ; écarté : <alternative>` (lien du ticket de suite pour un hors périmètre),
  dans la langue des PR du dépôt, puis :
  - ma PR existe : section `## Choix assumés` de sa description, créée à la fin du corps
    ou complétée (les points déjà là gardés, un même choix mis à jour plutôt que doublé) ;
    montrer la description modifiée, puis sur accord (`AskUserQuestion`, header
    « Description ») `gh pr edit <n> --body-file <fichier>` ;
  - pas encore de PR : les écrire dans le **fichier des choix assumés** de la branche,
    `$(git rev-parse --git-common-dir)/review-choices/<branche, « / » remplacés par « - »>.md`
    (complété, pas écrasé). `/git-tidy:pr-sync` et `/git-tidy:ready` les ajoutent à la
    description quand ils créent la PR, puis suppriment le fichier.

  Le but : qu'aucun relecteur ne refasse le même retour — `/review:pr` lit la description
  avant de signaler un écart au ticket, et `challenger` ne repropose pas un choix assumé.
- Brouillons de tickets de suite : les montrer, à reporter dans l'outil de tickets.
