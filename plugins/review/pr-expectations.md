# PR expectations (commun à `/review:diff`, `/review:pr` et `/review:feedback`)

Ce qu'on attend d'une PR, et donc du développement qu'elle porte. La revue vérifie ces
attentes de façon pragmatique, au **niveau d'exigence** que le dépôt déclare pour chaque
critère (voir plus bas) : un manque ne devient un constat que s'il a une conséquence
concrète ou enfreint une norme explicite.

## Les attentes

1. **Conforme à la demande** : le diff fait ce que le ticket demande, et chaque écart
   (ajout, retrait, changement) est justifié (voir `ticket.md`).
2. **Conforme aux normes en vigueur** pour le code, les tests, les commits et la PR
   (titre, description) : celles que le skill rassemble ci-dessous, quelle qu'en soit
   l'origine. Aucune norme trouvée sur un sujet → pas de règle inventée.
3. **Sûre**, au niveau d'exigence de chaque critère :
   - pas de bug, de faille ni de perte de données ;
   - le comportement ajouté ou modifié est vérifié par un test qui échouerait sans le
     changement, et aucun test existant n'est affaibli ou retiré sans raison ;
   - un changement de contrat (API, format, configuration, schéma) est compatible ou
     annoncé ; une migration de données est réversible, ou son retour arrière expliqué ;
   - aucune vérification (test, contrôle de CI, règle de build) n'est retirée ou
     contournée sans raison écrite.
4. **En un seul sujet** : sinon, un découpage est proposé (voir l'agent `reviewer`).

## Le niveau d'exigence

Chaque constat relève d'un **critère**, et le dépôt déclare, critère par critère, le
niveau qu'il attend :

| Critère (`critere`) | Ce qu'il couvre |
|---|---|
| `donnees` — fiabilité des données | exactitude, intégrité, données livrées ou validées, arrondis, unités |
| `contrat` — contrat et compatibilité | API, format échangé ou stocké, schéma, migrations |
| `reversibilite` | migration, suppression, retour arrière possible |
| `securite` | authentification, droits, entrées, secrets |
| `robustesse` | erreurs, dépendance externe indisponible, concurrence |
| `performance` | volumétrie, requêtes en boucle, chargements complets |
| `tracabilite` — traçabilité et audit | qui a fait quoi sur une donnée, logs utiles |
| `maintenabilite` | design, lisibilité, respect de l'architecture |
| `tests` | pertinence des assertions, cas limites |
| `ux` | ergonomie, messages d'erreur, accessibilité |
| `documentation` | ADR, glossaire, doc utilisateur |

Trois niveaux :

| Niveau | L'agent | Conseil des constats du critère |
|---|---|---|
| `faible` | ne relève que le défaut avéré, avec un scénario concret ; pas de `[nit]` | bug avéré : inchangé ; sinon une remarque, ou `optionnel` au plus |
| `normal` | relit comme d'habitude | inchangé |
| `élevé` | cherche activement (cas limites, scénarios d'échec, appelants) | tout manque de garde-fou (test, validation, compatibilité, retour arrière…) : `indispensable` |

Le skill établit le niveau de chaque critère, dans cet ordre :

1. **Déclaré** : une section des instructions du dépôt (`AGENTS.md`, `CLAUDE.md`,
   `CONTRIBUTING*`…) qui donne le niveau par critère, quel qu'en soit le titre, avec si
   possible le **pourquoi** de chaque niveau et des surcharges par chemin
   (`backend/domain/**` → `donnees` élevé). Elle l'emporte toujours.
2. **Déduit** : pour un critère qu'elle ne couvre pas (ou sans section), le reste du
   contexte disponible — README, instructions du dépôt, glossaire, ADR, ticket,
   instructions de la session. Seulement sur un fait écrit qui le justifie (« outil
   interne, 3 utilisateurs » → `performance` faible ; « données cliniques publiées » →
   `donnees` élevé ; « pas encore de production » → `reversibilite` faible), jamais sur
   une impression ; la source et l'extrait sont gardés comme pourquoi.
3. **`normal`** sinon.

Les niveaux déduits sont montrés à la validation, pour être corrigés si besoin ; s'il y
en a, la fin de la revue propose le texte à ajouter à la section du dépôt (ou de la
créer), pour qu'ils deviennent déclarés. Rien ne s'écrit dans le dépôt sans accord.
- **Ce que la CI garantit déjà** (couverture, règles d'architecture, format, lint) n'est
  pas relu : l'agent juge la pertinence (qualité d'une assertion), pas ce qu'un outil
  vérifie mieux que lui.
- **Le pourquoi se cite** : un commentaire sur un critère `élevé` peut reprendre la
  raison déclarée (« exigence élevée : la version validée part chez les clients »).

## La criticité

Ce que coûterait une erreur une fois la PR mergée — distincte de l'exigence, qui dit à quel
point on insiste sur un critère. Elle décide si une **relecture humaine attentive** est
requise.

- **Niveaux** : `basse`, `moyenne`, `haute`, ou **contexte manquant** quand l'impact ne
  peut pas être jugé : interaction avec l'infrastructure ou un système externe floue
  (configuration, déploiement, API ou données tierces), comportement qui dépend de données
  ou d'un environnement invisibles dans le dépôt, fichiers importants non lus.
- **Ce qui la fait monter** : irréversible (migration, suppression, écriture externe) ;
  rayon d'impact (code partagé, configuration par défaut, contrat public) ; échec
  silencieux ; rupture de contrat ; sécurité ; chaîne de build ; comportement modifié sans
  test ; diff qui fait plus ou autre chose que ce qu'annonce la PR ; zone sensible déclarée
  par le dépôt (quel que soit le titre de la section) ; critère d'exigence `élevé` touché.
- **Ce qu'elle donne** : le niveau, les zones à relire d'abord (`fichier:lignes`, avec ce
  qui peut casser), et ce qu'il faut pour revenir en arrière (un revert suffit, ou
  restauration de données, migration en deux temps, coordination…).
- **Relecture humaine requise** : `haute` ou contexte manquant.

**D'où elle vient**, dans cet ordre :

1. **Déjà donnée** : la PR (description, commentaire, corps d'une review) ou un message
   (commit, ticket) donne déjà un niveau de risque ou de criticité, posé par un bot ou un
   humain (le dernier en date l'emporte) → on le reprend, sans rien publier de plus.
   L'évaluation de l'agent n'apparaît alors que si elle est plus haute, en remarque.
2. **Un skill de la session** qui évalue le risque d'une PR, s'il y en a un, quel qu'il
   soit : lancé à la publication (il peut publier lui-même), jamais avant la validation.
3. **L'évaluation de l'agent** (`criticite`) sinon, en quelques lignes : niveau, zones,
   retour arrière.

## Le suivi des points

Chaque point d'une review publiée par `/review:pr` a un **statut**, tenu dans un
commentaire de suivi de la PR, un par relecteur, créé à sa première relecture et
maintenu à chacune des suivantes.

| Statut | Quand | Fil |
|---|---|---|
| ⏳ ouvert | ni correction ni réponse qui le règle | ouvert |
| ✅ corrigé | correction poussée, **vérifiée** dans le code de la tête de la PR (commit cité) | résolu |
| 💬 justifié | l'auteur explique pourquoi garder l'actuel, et le relecteur est convaincu | résolu |
| ☑️ accepté tel quel | point `optionnel` ou `discutable` (ou critère d'exigence `faible`) que l'auteur décline | résolu |
| 📌 reporté | traité hors de la PR, avec le **lien d'un ticket ou d'une issue** ; sans lien, il reste ouvert | résolu |
| 🗨️ en discussion | l'auteur a répondu, le relecteur n'est pas convaincu (ou attend une précision) | ouvert |

- **Le relecteur fait foi** : `/review:pr` établit les statuts, à la première review puis à
  chaque reprise. L'auteur ne peut pas modifier le commentaire d'un autre ; il annonce ses
  statuts dans ses réponses de fil (`/review:feedback` : « ✅ Corrigé dans `<sha>` »,
  « 💬 … », « 📌 Reporté : <lien> »), que la reprise vérifie.
- **Réglé** = corrigé, justifié, accepté tel quel ou reporté. **Reste** = ouvert ou en
  discussion, compté par conseil (bloquant, recommandé, autres).
- **Le commentaire**, dans la langue de la PR, commence par `<!-- review:suivi -->` (et
  est écrit par le relecteur : c'est ainsi qu'on retrouve le sien) :

  ```
  <!-- review:suivi -->
  **Suivi de la review** — à `<sha court de la tête>`, <date>
  | # | Point | Conseil | Statut |
  |---|---|---|---|
  | 1 | [`api.ts:42`](<lien du fil>) null non géré | bloquant | ✅ corrigé (`e4f5a6b`) |
  | 2 | Message du commit `a1b2c3d` | recommandé | ⏳ ouvert |
  **Reste** : 1 recommandé — approbation dès qu'aucun bloquant ni recommandé ne reste.
  ```

  Un point sans fil (écart dans le corps de la review) renvoie à la review. Rien ne reste :
  « **Reste** : rien ».
- **Approbation** (`/review:pr`) : pas tant qu'un point bloquant, indispensable ou
  recommandé reste ouvert ou en discussion — dans mon suivi comme dans les retours des
  autres relecteurs (leurs fils non résolus, leurs suivis).
- **Relance côté auteur** (`/review:feedback`) : pas tant que tous les fils et points de
  suivi ne sont pas traités (corrigés ou répondus).

## Rassembler les normes (le skill, pas l'agent)

L'agent part d'un contexte neuf : il ne voit pas les instructions de la session. Le skill
les rassemble donc et les lui transmet.

- **Le dépôt** : `CONTRIBUTING*`, template de PR (`.github/pull_request_template.md`,
  `.github/PULL_REQUEST_TEMPLATE/`, `docs/pull_request_template.md`), `AGENTS.md` et
  `CLAUDE.md` à la racine, et les documents qu'ils désignent pour le workflow, les
  conventions ou la *Definition of Done*. Pour une PR, à la version de sa branche de base
  (`git show origin/<base>:<fichier>`), sinon dans le working tree. À défaut de règle
  écrite pour le format des commits, l'usage de l'historique de la base
  (`git log --format=%s -20 origin/<base>`) en tient lieu.
- **La session** : les instructions, règles et skills présents dans la session courante
  qui portent sur le code, les tests, les commits ou les PR, quelle qu'en soit l'origine
  (fichier d'instructions, règle injectée, skill disponible). Les reprendre fidèlement,
  sans les compléter.
- **Priorité** : le dépôt l'emporte. Une norme de la session ne s'applique que sur ce que
  le dépôt ne dit pas ; en cas de contradiction, celle de la session est ignorée.

Les transmettre à l'agent dans un bloc **« Normes »**, par sujet (code et tests,
commits, PR), chaque règle avec sa source (chemin du fichier, ou « session ») — en
entier ou par extraits fidèles, pas un résumé qui en change le sens. Sujet sans norme :
l'écrire (« commits : aucune norme trouvée »). Les niveaux d'exigence vont dans un bloc
**« Exigences »** : pour chaque critère qui n'est pas `normal`, le niveau, s'il est
déclaré ou déduit, le pourquoi et sa source ; puis les surcharges par chemin ; « tous
normal » s'il n'y a rien. Lot de PR : rassemblées une fois, données à chaque agent.

## Travail en cours

Le dépôt est relu en cours de travail : l'historique n'est pas encore final.

- **Le code se juge sur le résultat** : le diff d'ensemble (`<base>...<tête>`), pas commit
  par commit. Un défaut introduit par un commit et corrigé par un suivant n'est pas un
  constat.
- **Tous les messages de commit sont lus**, et jugés comme un ensemble : les commits
  `fixup!`, `squash!`, `amend!` sont acceptés et ne sont pas jugés (ni leur message ni
  leur présence) ; ce qui sera fondu avant merge n'est pas un constat. Les normes de
  commit s'appliquent aux autres commits.
- **PR en brouillon** : description incomplète ou titre provisoire → une remarque, pas un
  constat.
- **`/review:diff`** : le working tree non commité n'a pas encore de message ; les normes
  de commit ne portent que sur les commits existants, celles de la PR seulement s'il y en
  a une.

## Dans `/review:feedback`

Les *PR expectations* servent à trier les retours reçus et à les corriger :

- retour appuyé sur une norme en vigueur ou sur une des *PR expectations* → conseil
  `indispensable`, la norme citée dans la réponse ;
- retour qui contredit une norme du dépôt ou une décision documentée → `très
  contestable`, la réponse cite la norme plutôt qu'un avis ;
- retour de goût, sans norme ni conséquence concrète → `discutable` ;
- retour sur un critère d'exigence `faible`, sans défaut avéré → `discutable`, réponse
  qui l'accepte tel quel en citant l'exigence ; sur un critère `élevé` → au moins
  `recommandé`.

Une correction respecte les *PR expectations* : un bug signalé est corrigé avec un test qui le couvre ;
une demande qui fait sortir du ticket est un écart à justifier (texte proposé pour la
description de la PR ou le ticket) ; un commit normal (ajout demandé) suit les normes de
commit rassemblées.
