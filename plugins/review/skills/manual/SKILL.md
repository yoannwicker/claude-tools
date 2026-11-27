---
name: manual
description: Relecture humaine guidée, dans une session séparée — d'une PR d'un collègue ou de son propre travail. L'agent mapper dresse la carte du diff ; la session affiche un résumé (endpoints, base et infra touchés, fonctionnalités par risque), puis le diff condensé pour une petite PR ou les axes d'analyse pour une grosse, et seulement ceux qui ont lieu d'être (fonctionnalité, use case et tests, refactoring, hors refactoring, SQL, Hibernate / infra, ticket) ; un menu prend mes retours à chaque étape. PR d'un collègue : mes remarques validées sont postées, avec un suivi séparé (<!-- review:suivi-manuel -->) qui bloque l'approbation de /review:pr tant qu'il est en cours. Mon travail : mes remarques deviennent des corrections ou une liste d'actions
argument-hint: "[numéro | recherche] [--cancel]"
disable-model-invocation: true
allowed-tools: Bash(gpr list:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr checks:*), Bash(gh issue view:*), Bash(gh api user:*), Bash(gh api graphql:*), Bash(gh repo view:*), Bash(git:*), Bash(difft:*), Bash(review-post:*), Bash(review-map-html:*), Bash(xdg-open:*), mcp__claude_ai_Atlassian_Rovo__getJiraIssue, Bash(acli jira workitem view:*), Bash(acli jira workitem comment list:*), Agent, Skill
---

Arguments : `$ARGUMENTS`

But : me donner le maximum d'information, de façon concise, lisible et **fidèle**, pour
que je repère moi-même ce qui ne va pas — et recueillir mes retours au fil de l'eau. La
session décrit, elle ne juge pas : les avis sont l'affaire de `/review:pr`,
`/review:diff` et `/review:decisions`. Elle répond à mes questions, mais ne propose pas de
constat d'elle-même. **Ne proposer que ce qui a lieu d'être** : un axe sans contenu (pas
de SQL, pas de refactoring…) n'apparaît nulle part.

## 1. La cible

- Numéro (`83`, `#83`) → cette PR ; texte → `gpr list <recherche>` (plugin `git-nav`),
  plusieurs résultats → demander (`AskUserQuestion`, header « PR ») ; sans argument → la
  PR de la branche courante, sinon la branche courante sans PR.
- PR : `gh pr view <n> --json number,id,title,body,url,state,author,baseRefName,headRefName,headRefOid,isDraft,commits,reviews`.
  Fermée ou mergée → le dire et s'arrêter.
- **Mode revue** : PR d'un autre. Ne pas se placer sur la PR : le diff et l'API suffisent
  (le worktree éventuel, ouvert par `review-watch open --worktree`, sert à naviguer dans
  l'IDE).
- **Mode auteur** : ma PR, ou ma branche sans PR (plage `<merge-base>...HEAD` plus le
  working tree, base comme `/review:diff`). Rien à relire → le dire et s'arrêter. Pas de
  suivi ni rien de posté.
- Le ticket : `${CLAUDE_SKILL_DIR}/../../ticket.md`. Les normes :
  `${CLAUDE_SKILL_DIR}/../../pr-expectations.md`, *Rassembler les normes* (bloc
  « Normes » seulement).
- **Le suivi manuel** (mode revue ; *Le suivi de la revue manuelle* de
  `pr-expectations.md`) : dans les commentaires de la PR (`gh api graphql`,
  `pullRequest(number:) { comments(first: 100) { nodes { id author { login } body url createdAt } } }`),
  le mien qui commence par `<!-- review:suivi-manuel -->` — son `id` et son état.
  - `--cancel` : le passer à « abandonnée » (« Relecture manuelle abandonnée — ne bloque
    plus l'approbation »), donner son lien et s'arrêter. Aucun → le dire et s'arrêter.
  - « terminée » avec des points encore ouverts ou en discussion → **reprise** : relire
    les fils de ces points (`reviewThreads`, comme l'étape 1 de `/review:pr`), les traiter
    comme *Reprise : mes fils* de `${CLAUDE_SKILL_DIR}/../pr/SKILL.md` (résoudre,
    répondre, laisser), puis mettre le suivi manuel à jour et proposer de relire ce qui a
    changé depuis (la carte ne porte alors que sur `<commit du suivi>...headRefOid`).
  - « en cours » (posé par `/review:pr`, ou passage interrompu) → continuer.
  - Absent, ou « terminée » sans rien d'ouvert → le créer ou le repasser à « en cours »
    tout de suite (lancer la relecture vaut accord) et le dire en une ligne avec son
    lien : `/review:pr`, lancé en parallèle ou par `review-watch`, sait ainsi qu'il ne
    doit pas approuver.

## 2. La carte

Lancer l'agent `review:mapper` (outil Agent) avec la cible (« PR #<n> », `headRefOid` et
la base, ou la plage et « working tree inclus »), le ticket et le bloc « Normes ». Il rend
du JSON : c'est **la carte**, calculée une fois ; tout ce qui suit la lit, sans relancer
d'agent.

**Vérifier le bruit** : chaque hunk classé `renommage`, `deplacement`, `genere` ou
`format` est contrôlé (`git diff -w -M`, `git diff --color-moved=plain
--color-moved-ws=allow-indentation-change`, `difft` s'il est installé). Au moindre
doute, il repasse en `comportement` : on ne cache jamais ce qui pourrait compter. Le
diff vient de `gh pr diff <n>` (ou `git diff <base>...<tête>`, plus le working tree en
mode auteur) ; le code montré est toujours celui du diff, tel quel, jamais reformulé.

## 3. Le résumé, puis le diff condensé ou les axes

**Le résumé**, toujours en premier, une douzaine de lignes ; une ligne absente quand
elle n'a rien à dire :

```
#482 · ABC-123 · +612 −148 · 23 fichiers · à vraiment relire : 310 lignes sur 760
Besoin : …   Livré : …   Pas fait : …   En plus : …
Endpoints : + POST /panier/remise · ~ GET /panier (champ `detail` ajouté)
Base : + migration V42 (colonne remise.taux, NOT NULL) · ~ requête PanierRepository.findActifs
Infra : ~ entité Remise (taux non nullable) · + client TarifApi
Fonctionnalités touchées (par risque) :
  ⚠️ Calcul des remises     +180 −40   cache non invalidé, cumul de codes non testé
  •  Affichage du panier    +60 −12    nouveau champ `detail` (compatible)
  ↻  Refactoring            +90 −70    RemiseService découpé en 2
  ·  Bruit                  +250 −60   renommage Discount → Remise, lockfile
Ticket : 3 critères faits, 1 partiel, 1 non trouvé
```

Puis, dans le même message :

- **petite PR** (moins de 150 lignes à relire) : le **diff condensé** (axe 1 ci-dessous),
  directement ;
- **grosse PR** : les **axes d'analyse** qui ont lieu d'être, numérotés, une ligne
  chacun avec ce qu'on y verra (« 2. Calcul des remises — arrondi, cache, 4 fichiers »),
  la fonctionnalité la plus risquée en premier.

## 4. Le menu

Après le résumé, et après chaque axe affiché ou chaque réponse : une question
(`AskUserQuestion`, header « Suite »), dont « Autre » est **la case de retour** — le
dire dans la question (« un retour ou une question ? écris-le dans Autre ») :

- options : jusqu'à 2 axes pas encore vus et qui ont lieu d'être, le recommandé en premier
  (petite PR : *Use case et tests*, puis ce qui reste ; grosse PR : la fonctionnalité la
  plus risquée pas encore vue, puis *Hors refactoring* ou *Refactoring*), puis **Autre
  axe** (la liste numérotée des axes restants, et le menu revient pour en choisir un),
  puis **Terminer** ;
- **la case de retour** (« Autre ») :
  - une **remarque** → la noter : `fichier:ligne` (demander s'il n'est pas clair), mon
    texte, et le conseil que j'indique (sinon `recommandé`) ; confirmer en une ligne
    (« noté (#3) ») ;
  - une **question** (« qui appelle X ? », « que se passe-t-il si… », « montre-moi… »)
    → y répondre en lisant le code, court, avec `fichier:ligne` ; ouvrir le diff dans
    l'IDE si je le demande ;
  - un numéro d'axe → cet axe ;

  puis le même menu revient : je peux enchaîner les retours sans changer d'axe.

## 5. Les axes

Seulement ceux qui ont lieu d'être, chacun concis, avec `fichier:ligne` partout et le code
tel qu'il est dans le diff :

1. **Diff condensé** — la version fidèle et courte : seulement les hunks qui comptent,
   regroupés par fonctionnalité (par risque), chacun précédé de sa ligne de résumé ; le
   bruit et le refactoring repliés en une ligne chacun (« renommage Discount → Remise : 6
   fichiers, 300 lignes »). Grosse PR : une fonctionnalité à la fois.
2. **Une fonctionnalité** (un axe par fonctionnalité, grosse PR) — la fiche : fonctionnel
   (avant → après, l'exemple), technique, contrats, risques, à lire, angles morts ; puis
   ses hunks `comportement` en diff condensé.
3. **Use case et tests** (s'il y a des hunks `comportement`) — sans les lignes de code :
   pour chaque fonctionnalité, le point d'entrée et la chaîne des symboles modifiés (ce
   qui change dans chacun), puis les tests qui la couvrent (nom, `fichier:ligne`, ce
   qu'ils vérifient, nouveau ou existant) et ce qu'aucun test ne couvre.
4. **Refactoring** (s'il y en a) — pour chacun : ce qui est fait, pourquoi (et sa
   source : commit, PR, ticket, ou « déduit »), ce qu'il touche (symboles, appelants,
   fichiers), et ce qui montre que le comportement est préservé — ou que rien ne le
   montre. Le diff des hunks concernés seulement à la demande.
5. **Hors refactoring** (s'il y a à la fois du refactoring, des déplacements ou des
   renommages, et du comportement) — le diff des seuls hunks `comportement` (et
   `migration`, `config`) : ce que la PR change vraiment. Pour un fichier qui mêle les
   deux, diff algorithmique : `difft --display inline` s'il est installé, sinon `git diff
   -w -M --color-moved=dimmed-zebra --color-moved-ws=allow-indentation-change` restitué
   en texte (lignes déplacées marquées comme telles).
6. **SQL** (s'il y a des hunks `sql`) — le diff complet : migrations, schéma, scripts,
   requêtes natives et JPQL/HQL (même dans un fichier Java), chaque requête avec sa
   méthode et son appelant ; pour une migration, ce qu'elle fait sur les données
   existantes et si elle est réversible.
7. **Hibernate / infra** (s'il y a des entités, mappings, repositories ou une config de
   persistance ou de service externe modifiés) — le diff simplifié : par entité, les
   changements de champ, colonne, type, `nullable`, relation, `fetch`, `cascade`,
   `orphanRemoval`, index, version, avant → après en une ligne chacun ; les repositories
   (méthode ajoutée ou modifiée, requête dérivée) ; la config (clé, avant → après). Le
   diff brut d'un fichier à la demande.
8. **Ticket** (s'il y a un ticket) — chaque critère : fait, partiel ou non trouvé, avec où
   dans le code ; ce que la PR fait en plus.
9. **Exporter la carte en HTML** (grosse PR) — une page locale pour la parcourir à son
   rythme à côté du terminal : écrire dans le scratchpad la carte (`carte.json`, avec le
   bruit vérifié) et le diff (`diff.patch` : `gh pr diff <n>`, ou `git diff <merge-base>`
   en mode auteur), puis `review-map-html carte.json diff.patch carte.html` (dans le `bin/`
   du plugin) et `xdg-open carte.html`. Page segmentée : une section à la fois, choisie
   dans le sommaire latéral (risque de chaque fonctionnalité affiché) ou avec ←/→ (j/k) et
   Précédente / Suivante. Sections : résumé, une par fonctionnalité (fiche et diff de ses
   seuls hunks, rendu par diff2html), refactoring, SQL, Hibernate, ticket, bruit replié. Donner son chemin complet ; mes retours restent dans le menu (en citant la
   fonctionnalité ou `fichier:ligne`). Rien n'est publié : la page ne charge que diff2html
   depuis cdn.jsdelivr.net.

## 6. Mes remarques

**Terminer** : le tableau de mes remarques (n°, conseil, `fichier:ligne` ou « corps »,
remarque). Aucune remarque → le dire, puis l'étape 7.

**Mode revue** : chaque remarque rédigée **telle qu'elle sera postée** — pour l'auteur,
dans la langue de la PR, courte, ma remarque fidèlement reprise (pas d'argument ajouté),
préfixe selon le conseil (`[bloquant]` indispensable, rien pour recommandé, `[nit]`
optionnel, `[question]` question). Validation comme dans
`${CLAUDE_SKILL_DIR}/../../validation.md` (*Validation en liste*), puis poster
directement (la validation vaut accord) : `review.json` dans le scratchpad (`{"body":
"<Relecture manuelle : remarques sans ligne>", "comments": [{"path", "line", "body"}…]}`)
et `review-post <n> review.json` — une review `COMMENT`, jamais `REQUEST_CHANGES`. Code 3
(review en attente à moi) : comme l'étape 4 de `/review:pr`.

**Mode auteur** : demander (`AskUserQuestion`, header « Remarques ») : **Corriger
maintenant (Recommandé)** — dans le working tree, sans commit ni `git add`, comme
`/review:diff` — / **Garder la liste** (à reprendre plus tard ; rien n'est modifié).

## 7. Le suivi manuel et l'approbation (mode revue)

Mettre à jour le suivi manuel (*Le suivi de la revue manuelle* de `pr-expectations.md`),
comme le suivi de l'étape 4 de `/review:pr` (`suivi-manuel.md` dans le scratchpad,
`updateIssueComment` s'il existe, sinon `addComment`) : état « terminée » à
`<sha court de headRefOid>`, mes remarques postées (statut ouvert) reliées à leur fil
(relire les fils, associer par chemin et ligne ; sans fil, lien de la review), les statuts
validés d'une reprise, et ce qui reste par conseil. Aucune remarque : « **Reste** : rien
— relecture manuelle sans remarque ».

**Approbation** : le suivi « terminé », si rien d'indispensable ni de recommandé n'y reste
ouvert et que les conditions d'approbation de `/review:pr` (*Approbation*, étape 3 de
`${CLAUDE_SKILL_DIR}/../pr/SKILL.md`) sont remplies — la revue de code est faite (mon
suivi `<!-- review:suivi -->` existe ; sinon le dire : « revue de code pas encore faite :
`/review:pr <n>` ») et n'y laisse rien d'indispensable ni de recommandé ouvert ; retours
des autres ; brouillon — proposer d'approuver (`AskUserQuestion`, header « Approuver »,
CI citée par `gh pr checks <n>`) : **Approuver (Recommandé)** / **Ne pas approuver** ; CI
rouge : **Ne pas approuver** en premier. Approuver : `review-post <n> <json vide>
--approve`, puis mettre mon suivi `review:suivi` à jour (« **Reste** : … — approuvée à
`<sha>` »).

## 8. Fin

- Mode revue : l'URL de la review, le nombre de commentaires inline et dans le corps, le
  lien du suivi manuel et ce qui reste, l'approbation s'il y en a eu une.
- Mode auteur : les fichiers modifiés (rappeler de relire `git diff`), ou la liste gardée.
- Le chemin de la carte HTML s'il y en a une. Worktree ouvert pour cette relecture
  (`agent/review-<n>-…`) : proposer le ménage comme l'étape 5 de `/review:pr`.
