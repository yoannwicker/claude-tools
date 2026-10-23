# Docs de suivi

Suivi de l'usage des agents (Claude Code, Copilot) et de ce qu'on en tire pour faire évoluer
cette config.

## `analyses-sessions/`

Rapports bruts d'analyse des sessions, produits par Claude, un fichier par analyse :
`AAAA-MM-JJ.md` (date du jour de l'analyse).

- Un rapport couvre les 30 jours qui précèdent sa date, en global puis pour les 4 projets
  les plus actifs sur cette période.
- Un rapport n'est plus modifié une fois écrit : c'est un instantané.
- Chaque rapport suit la même méthode et le même tableau d'indicateurs que le précédent, et
  se compare à lui (section *Évolution*), pour qu'on puisse suivre les tendances d'un
  rapport à l'autre.
- Les recommandations d'un rapport sont des propositions : seules celles qu'on retient
  passent dans `pistes-amelioration/`.

## `pistes-amelioration/`

Les pistes retenues à l'issue des rapports, et les idées proposées en dehors. Un fichier par
piste, préfixé par sa priorité :

```
<priorité>-<nom-court>.md     ex. 1-plugin-analyse-sessions.md
```

| Priorité | Sens |
|----------|------|
| `1` | à faire en premier |
| `2` | ensuite |
| `3` | quand il y a le temps |

Changer de priorité, c'est renommer le fichier. En tête de chaque piste :

```
- **Statut** : proposée | validée | en cours | faite | abandonnée
- **Origine** : rapport du AAAA-MM-JJ, ou idée
```

Une piste faite ou abandonnée reste dans le dossier, avec son statut et le lien vers le
commit ou la raison de l'abandon.
