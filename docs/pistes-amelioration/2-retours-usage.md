# Retours sur l'usage de Claude

- **Statut** : faite
- **Origine** : idée d'un collègue (2026-10-28)

## Besoin

Garder le ressenti sur ce qui sert pendant les sessions (skills, plugins, hooks, consignes,
MCP) : ce que les chiffres d'AgentsView ne disent pas. Retours personnels, notés en fin de
session, **à la demande** (pas de hook qui les sollicite).

## Réalisation

Skill [`/session-analysis:feedback`](../../CLAUDE-CODE.md#session-analysisfeedback) dans le
plugin `session-analysis`, plutôt qu'un plugin à part : même finalité que les rapports.

Choix faits :

- **Journal personnel** hors du dépôt (`~/.local/share/session-analysis/feedback.jsonl`),
  une ligne par retour : cible, avis (positif, négatif, suggestion), texte, session, projet.
- **Validation** de chaque retour avant écriture ; Claude propose des retours tirés de la
  session si l'utilisateur n'en donne pas.
- **Repris par le rapport** : bloc `feedback` d'`indicators.json` et section *Retours* de
  `/session-analysis:report`, rapprochée des constats chiffrés ; `/session-analysis:session`
  cite les retours de la session et propose d'en noter un.
