# PR expectations (commun à `/review:diff`, `/review:pr` et `/review:feedback`)

Ce qu'on attend d'une PR, et donc du développement qu'elle porte. La revue vérifie ces
attentes de façon pragmatique : un manque ne devient un constat que s'il a une conséquence
concrète ou enfreint une norme explicite.

## Les attentes

1. **Conforme à la demande** : le diff fait ce que le ticket demande, et chaque écart
   (ajout, retrait, changement) est justifié (voir `ticket.md`).
2. **Conforme aux normes en vigueur** pour le code, les tests, les commits et la PR
   (titre, description) : celles que le skill rassemble ci-dessous, quelle qu'en soit
   l'origine. Aucune norme trouvée sur un sujet → pas de règle inventée.
3. **Sûre** :
   - pas de bug, de faille ni de perte de données ;
   - le comportement ajouté ou modifié est vérifié par un test qui échouerait sans le
     changement, et aucun test existant n'est affaibli ou retiré sans raison ;
   - un changement de contrat (API, format, configuration, schéma) est compatible ou
     annoncé ; une migration de données est réversible, ou son retour arrière expliqué ;
   - aucune vérification (test, contrôle de CI, règle de build) n'est retirée ou
     contournée sans raison écrite.
4. **En un seul sujet** : sinon, un découpage est proposé (voir l'agent `reviewer`).

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
l'écrire (« commits : aucune norme trouvée »). Lot de PR : rassemblées une fois, données
à chaque agent.

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
- retour de goût, sans norme ni conséquence concrète → `discutable`.

Une correction respecte les *PR expectations* : un bug signalé est corrigé avec un test qui le couvre ;
une demande qui fait sortir du ticket est un écart à justifier (texte proposé pour la
description de la PR ou le ticket) ; un commit normal (ajout demandé) suit les normes de
commit rassemblées.
