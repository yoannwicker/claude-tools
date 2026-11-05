# review : faire le point sur mes PR

- **Statut** : abandonnée — fusionnée dans [gh-watch : tableau de bord des PR](1-gh-watch-board.md)
- **Origine** : idée (2026-11-05)

## Constat

Le plugin `review` agit PR par PR (`/review:pr`, `/review:feedback`) et `review-watch`
réagit aux événements, mais rien ne donne d'un coup l'état de toutes mes PR ouvertes ni
des relectures qu'on attend de moi : il faut aller voir GitHub, dépôt par dépôt.

## Proposition

Un skill `/review:status` (ou `/review:mine`) qui fait le point, tous dépôts confondus
(recherche GitHub `author:@me` et `review-requested:@me`) :

- **mes PR** : brouillon, en attente de relecture (qui est demandé, depuis quand),
  changements demandés, retours non résolus (combien de fils, en attente de ma réponse ou
  du relecteur), approuvée (N/N attendues), en retard sur sa base, CI en échec ;
- **relectures attendues de moi** : PR, auteur, depuis quand, déjà relue puis redemandée ;
- pour chaque ligne, l'action proposée (`/review:feedback <n>`, `/review:pr <n>`,
  relancer un relecteur…) et, si `review-watch` a déjà lancé une session, son état
  (`gh-watch status`).

## À trancher

- Recoupe [la vue des PR de gh-watch](3-gh-watch-vue-pr.md) et [le scan GitHub](2-scan-github-actions-pr.md) :
  un seul calcul des états, porté par `review` (ses PR et relectures) et repris par
  `gh-watch` pour la vue d'ensemble, plutôt que deux.
- Commande terminal en plus du skill (`review-watch prs` ?) ou skill seulement.
- Seuil d'approbations : celui de `git-tidy` (`approvals` de `git-tidy.json`) si le
  plugin est là, sinon 2.
