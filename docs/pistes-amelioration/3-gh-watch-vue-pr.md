# gh-watch : vue des PR en cours

- **Statut** : abandonnée — fusionnée dans [gh-watch : tableau de bord des PR](1-gh-watch-board.md)
- **Origine** : idée (2026-11-05)

## Constat

`gh-watch status` montre les watchers (timers, dépôts, sessions, déclenchements), pas les
PR elles-mêmes : mes PR ouvertes, celles qui attendent ma relecture, celles qui attendent
une relecture des autres, approuvées, en validation…

## Proposition

Un réglage ou une option (`gh-watch prs`, `/gh-watch:status --prs`) qui liste les PR des
dépôts suivis par état : à relire par moi, en attente de relecture, retours à traiter,
approuvées, en validation (JIRA), prêtes à merger.

## À trancher

- Utile seulement si l'on ne lance pas tout automatiquement : avec les modes auto, les
  sessions et l'historique des déclenchements disent déjà l'essentiel. À reprendre après
  la piste [scan GitHub](2-scan-github-actions-pr.md), qui calcule les mêmes états.
- Recoupe [le point sur mes PR du plugin `review`](2-review-point-mes-pr.md) : la vue de
  `gh-watch` pourrait simplement reprendre celle-ci.
