# Docs de suivi

Suivi de l'usage des agents (Claude Code, Copilot) et de ce qu'on en tire pour faire évoluer
cette config.

## `analyses-sessions/`

Rapports bruts d'analyse des sessions, produits par Claude, un fichier par analyse :
`AAAA-MM-JJ.md` (date du jour de l'analyse), et ses indicateurs bruts dans
`AAAA-MM-JJ.json`.

- Un rapport couvre les 30 jours qui précèdent sa date, en global puis pour les 4 projets
  les plus actifs sur cette période.
- Un rapport n'est plus modifié une fois écrit : c'est un instantané.
- Chaque rapport suit la même méthode et le même tableau d'indicateurs que le précédent, et
  se compare à lui (section *Évolution*), pour qu'on puisse suivre les tendances d'un
  rapport à l'autre.
- Les recommandations d'un rapport sont des propositions : seules celles qu'on retient
  passent dans `pistes-amelioration/`.

### Produire un rapport

`/session-analysis:report [projet…]` (plugin
[`session-analysis`](../CLAUDE-CODE.md#session-analysis)) collecte les données et porte la
méthode générale (période, projets suivis, structure du rapport). Ce qui est propre à ce
dépôt :

- écrire le rapport dans `docs/analyses-sessions/AAAA-MM-JJ.md` (date du jour ; un suffixe
  `-<projet>` si le rapport ne porte que sur des projets demandés) ;
- copier à côté, sous le même nom en `.json`, l'`indicators.json` produit par la collecte :
  les chiffres bruts du rapport, ce qui sert à le comparer ;
- le comparer au rapport le plus récent du dossier qui porte sur les mêmes projets, en
  lisant son `.json` (son tableau Markdown à défaut) : section *Évolution*, indicateur par
  indicateur (amélioré, dégradé, stable), et pour chaque piste de `pistes-amelioration/`
  en cours ou faite, dire si son indicateur a bougé ;
- section *Retours* : les retours notés avec `/session-analysis:feedback` sur la période ;
  le rapport du 2026-10-23 n'en avait pas (bloc `feedback` d'`indicators.json` absent) : le
  premier rapport qui l'a le signale dans *Méthode* ;
- reprendre la méthode et le tableau d'indicateurs du rapport précédent ; si la méthode
  change (nouvel indicateur, autre calcul), le dire dans la section *Méthode* ;
- ne pas créer de piste : les proposer en fin de rapport, l'utilisateur choisit celles qui
  passent dans `pistes-amelioration/` et leur priorité.

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
