# Plugin d'analyse des sessions

- **Statut** : faite
- **Origine** : idée (2026-10-23)

## Besoin

Produire les rapports de `docs/analyses-sessions/` sans refaire la méthode à la main, et
pouvoir analyser une session à sa fin. Déclenchable **uniquement à la demande** : pas de
hook automatique.

## Réalisation

Plugin [`session-analysis`](../../CLAUDE-CODE.md#session-analysis) :

1. **`/session-analysis:report [projet…] [--days N]`** : 30 derniers jours, en global puis
   pour les 4 projets les plus actifs (ou ceux demandés) ; ce qui s'est amélioré ou
   dégradé, pistes d'amélioration.
2. **`/session-analysis:session [id]`** : bilan de la session en cours (note, échecs et
   refus, allers-retours, prompts, consignes), pistes et conseils, dans la conversation.

Choix faits :

- **Méthode « iso »** : les règles générales sont dans le skill `report`, la collecte dans
  le script `session-analysis-collect` (mêmes indicateurs à chaque fois,
  `indicators.json`) ; ce qui est propre à ce dépôt (emplacement, comparaison avec le
  rapport précédent) est dans [docs/README.md](../README.md).
- **Bilan de session** : reste dans la conversation, n'est pas archivé.
- **AgentsView** : installé par `./install.sh plugin session-analysis`, lancé par les
  skills s'il ne tourne pas (`agentsview-up`).
- **Indicateurs bruts** : `indicators.json` est gardé à côté de chaque rapport
  (`docs/analyses-sessions/AAAA-MM-JJ.json`), et c'est lui qui sert à comparer.
