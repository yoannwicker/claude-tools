# Retours sur l'usage de Claude

- **Statut** : faite
- **Origine** : idée d'un collègue (2026-10-28)

## Besoin

Juger, en fin de session, les éléments de la config qui ont servi (skills, plugins, hooks,
consignes, MCP) : ce que les chiffres d'AgentsView ne disent pas. Claude fait l'analyse
selon des angles fixes ; l'utilisateur donne son avis sur chaque constat et ajoute les
siens. **À la demande** (pas de hook qui le sollicite).

## Réalisation

Skill [`/session-analysis:feedback`](../../CLAUDE-CODE.md#session-analysisfeedback) dans le
plugin `session-analysis`, plutôt qu'un plugin à part : même finalité que les rapports.

Choix faits :

- **Analyse par angles** : déclenchement, résultat, friction, consignes, outillage,
  manques ; au plus 6 constats, chacun appuyé sur un fait de la session.
- **Avis de l'utilisateur** sur chaque constat (d'accord, nuancé, pas d'accord, écarté) :
  un désaccord est gardé, il dit où l'analyse de Claude se trompe.
- **Journal** par défaut hors du dépôt (`~/.local/share/session-analysis/feedback.jsonl`),
  ailleurs avec un `.session-analysis.json` (commitable dans un projet) ; une ligne par
  retour : source, angle, cible, avis, texte, avis de l'utilisateur, session, projet.
- **Repris par le rapport** : bloc `feedback` d'`indicators.json` et section *Retours* de
  `/session-analysis:report`, rapprochée des constats chiffrés ; `/session-analysis:session`
  cite les retours de la session et propose d'en noter un.
