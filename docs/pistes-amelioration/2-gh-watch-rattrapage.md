# gh-watch : rattrapage quotidien, avec validation avant lancement

- **Statut** : proposée
- **Origine** : idée (2026-11-05)

## Constat

`review-watch` détecte les demandes de revue par les notifications GitHub
(`review_requested`) depuis le dernier passage : c'est événementiel. Des demandes lui
échappent :

- quand je me demande moi-même une revue sur la PR d'un collègue, GitHub ne me notifie pas
  de ma propre action (cas réel : softwarevidal/renoshield#205, absent de l'état et de
  l'historique de `review-watch`, alors que `review-requested:@me` la trouve) ;
- notification marquée lue ou archivée à la main, passage en erreur…

`feedback` (review-watch) et `approved` (tidy-watch) sont déjà fondés sur l'état : chaque
`poll` parcourt mes PR ouvertes et les compare à `state[kind]`, ce qui n'est pas traité
revient au passage suivant. Exception : `dispatch` marque l'événement traité même quand le
lancement échoue, un échec n'est donc jamais relancé.

## Proposition

Un rattrapage fondé sur l'état actuel de GitHub, pour les dépôts dont l'événement est en
`auto`, sans modifier la détection de `poll`.

- **Watchers** (watchlib) : `w.main(…, catchup=…)`, fonction qui donne les éléments à
  rattraper ; watchlib ne garde que le mode `auto` et applique les filtres communs (déjà
  traité, refusé à cette date). Sous-commandes communes : `catchup [--json]` (détection
  seule), `launch <repo#n> <kind> --at <date>` (lance et marque traité, comme `poll`),
  `skip <repo#n> <kind> --at <date>` (refusé : `state[kind] = date` + historique
  « refusé » ; un nouvel événement le fait revenir).
- **review-watch** : `is:pr is:open review-requested:@me archived:false`, puis les mêmes
  filtres que `poll` (PR fermée ou à moi, déjà relue depuis la demande), extraits dans une
  fonction commune. `feedback` et tidy-watch : rattrapage vide (déjà fondés sur l'état ;
  les proposer ferait doublon avec le `poll` suivant).
- **gh-watch** : état propre (`~/.local/state/claude-tools/gh-watch/state.json` : jour du
  dernier rattrapage, éléments en attente). `gh-watch catchup [--daily] [--dry-run]
  [--json]` interroge chaque watcher, enregistre la liste, envoie **une** notification
  (« N éléments à rattraper », rien si 0) dont le clic ouvre un terminal sur
  `/gh-watch:catchup`. `gh-watch catchup launch|skip …` relaie au watcher et retire
  l'élément de la liste.
- **Premier passage de la journée** : à la fin de `poll` (verrou du watcher relâché, sinon
  interblocage avec `catchup --json`), watchlib lance en détaché `gh-watch catchup
  --daily` si le dernier rattrapage date d'avant aujourd'hui. Pas de nouveau timer.
- **Skill `/gh-watch:catchup`** : tableau (dépôt#n, événement, titre, auteur, date),
  sélection multiple (`AskUserQuestion` : 16 éléments au plus par tour), lancement des
  éléments retenus par le mécanisme existant (herdr, sinon analyse en fond). Fermée sans
  choix : rien n'est enregistré, l'élément revient au prochain rattrapage.
- **Supervision** : `gh-watch status` affiche le dernier rattrapage et les éléments en
  attente ; `/gh-watch:status` les liste, et les signale dans « ce qui cloche » s'ils
  attendent depuis plus d'un jour.

Hors périmètre : un mode `confirm` par dépôt (il pourrait réutiliser cette liste plus
tard).

## À trancher

- Faire ou non : le cas manqué principal (revue que je me demande moi-même) est peut-être
  assez rare pour se contenter d'un `review-watch launch` à la main.
- Éléments non cochés dans la sélection : refusés, ou une option « plus tard » qui ne les
  enregistre pas.
- Lancements en échec : les reproposer (en lisant la dernière entrée d'historique de la
  clé), ou s'en tenir à la notification d'échec, déjà relançable au clic.
- Confirmer le rattrapage vide pour `feedback` et `approved`.
- Recoupe [le point sur mes PR du plugin `review`](2-review-point-mes-pr.md) et
  [la vue des PR de gh-watch](3-gh-watch-vue-pr.md), qui font la même recherche
  `review-requested:@me` : un seul calcul à partager.
