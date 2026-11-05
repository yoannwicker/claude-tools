# Scan GitHub : déclencher directement la bonne action sur une PR

- **Statut** : abandonnée — fusionnée dans [gh-watch : tableau de bord des PR](1-gh-watch-board.md)
- **Origine** : idée (2026-11-05)

## Constat

Les watchers ([`gh-watch`](../../CLAUDE-CODE.md#gh-watch)) réagissent à des événements :
une demande de review (`review-watch`), une review reçue (`review-watch`), une PR qui
atteint ses approbations (`tidy-watch`). Ce qui est déjà en attente avant l'activation
(`enable` l'enregistre sans rien lancer) ou ce qui n'arrive pas par un événement (PR en
retard sur `main`, PR approuvée mais jamais préparée) reste à repérer à la main.

## Proposition

Un scan à la demande de toutes mes PR et de celles où l'on m'attend, qui propose
directement l'action utile pour chacune, et la lance après choix :

- relecture demandée et pas faite → `/review:pr` ;
- retours non traités sur ma PR → `/review:feedback` ;
- PR en retard sur sa base (ou PR de pile décalée) → rebase (`/git-tidy:pr-sync`, étape 2) ;
- PR approuvée pas encore préparée → `/git-tidy:ready` (passage en validation compris).

## À trancher

- Où : commande `gh-watch scan` (et `/gh-watch:scan`) qui interroge chaque watcher (nouvelle
  commande `<watcher> scan --json` : « à faire » sans tenir compte de ce qui est déjà
  enregistré), ou un skill autonome.
- Lancement : par `<watcher> launch` (herdr ou fond, comme le mode auto) ou dans la session
  courante.
- Le rebase n'est pas un événement de watcher aujourd'hui : nouvel événement `behind` dans
  `tidy-watch`, ou seulement dans le scan.
