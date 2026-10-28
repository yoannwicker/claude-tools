# Priorisation et validation (commune aux skills du plugin `review`)

Rien n'est envoyé, publié ni modifié avant la fin de cette validation.

## Conseil

Chaque point (constat de revue ou retour reçu) porte un conseil, et la liste est triée par
conseil puis gravité :

| Conseil | Sens |
|---|---|
| `indispensable` | bug, faille, perte de données, règle explicite du dépôt enfreinte |
| `recommandé` | gain net, coût raisonnable |
| `optionnel` | mieux, mais sans conséquence si on laisse |
| `discutable` | gain incertain, se défend dans les deux sens |
| `très contestable` | goût, doute, coût supérieur au gain |

## Validation en liste (par défaut)

1. Tableau numéroté, une ligne par point : `n°`, conseil, `fichier:ligne`, constat en une
   ligne, proposition en une ligne. Les points `à approfondir` sont marqués `🔎` et
   restent dans la liste.
2. Une seule question (`AskUserQuestion`, header « Points ») :
   - **Tout sauf « très contestable » (Recommandé)** ;
   - **Indispensables seulement** ;
   - **Tout** ;
   - « Autre » : numéros à garder ou à écarter, reformulations (`3 : dire plutôt …`).

## Un par un (seulement pour les points `🔎` gardés)

Un point mérite d'être approfondi quand il demande une explication ou un arbitrage :
choix métier, plusieurs solutions valables, refactoring, découpage, désaccord probable.
Pour chacun, après la liste : explication détaillée, extrait de code, options avec leurs
compromis et une recommandation, puis une question dédiée (header court, 2 à 4 options,
la recommandée en premier). « Autre » → texte libre.

## Fin

Récapitulatif de ce qui va être fait (et de ce qui est écarté), puis exécution. Une
action extérieure (publication sur GitHub, push) n'est faite que si la validation la
couvre explicitement.
