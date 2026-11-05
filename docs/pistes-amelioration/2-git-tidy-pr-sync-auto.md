# git-tidy : `/git-tidy:pr-sync-auto`, rebaser d'office une PR en retard

- **Statut** : proposée
- **Origine** : idée (2026-11-05), en faisant la liste interactive de
  [gh-watch board](1-gh-watch-board.md)

## Constat

`gh-watch board` signale mes PR en retard sur leur base (alerte « en retard ») et propose
`/git-tidy:pr-sync`, mais ne peut pas le lancer : aucun watcher ne gère cet état, et
`pr-sync` n'a pas de mode `--prepare` (analyse en fond sans rien réécrire ni pousser, comme
`/git-tidy:ready`). Le rebase reste donc à lancer à la main, depuis un clone.

## Proposition

Sur le modèle de `/git-tidy:approved-auto` :

- `pr-sync --prepare` : situation (retard sur la base, pile et PR décalées, conflits
  prévisibles) sans rebaser, brouillons de description et de ticket sans question, rien
  poussé ni publié, pas de changement de branche (ce que `/git-tidy:ready --prepare` fait
  déjà pour son étape pr-sync) ;
- un événement `behind` dans `tidy-watch` (mode par dépôt `auto` / `notify` / `off`, `off`
  par défaut) : une de mes PR, hors brouillon, a N commits de retard sur sa base, ou sa PR
  de base a bougé (pile) ;
- `/git-tidy:pr-sync-auto on|off` pour l'activer par dépôt ;
- dans `gh-watch board`, l'état devient géré (`board={"behind": …}` ou alerte suivie) : la
  ligne se lance (`Entrée`, `f` dans `board -i`) et peut être manquée.

## À trancher

- Seuil de retard (nombre de commits, ou tout retard) et cas de la pile.
- Rebaser pendant la revue : seulement si aucun relecteur n'est en cours de relecture, ou
  toujours avec validation dans la session.
- Alerte (cumulable avec l'état) contre événement : `board` ne déclare aujourd'hui que des
  états ; suivre une alerte demande de l'étendre.
