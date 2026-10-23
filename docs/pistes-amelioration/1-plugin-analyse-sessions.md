# Plugin d'analyse des sessions

- **Statut** : proposée
- **Origine** : idée (2026-10-23)

## Besoin

Produire les rapports de `docs/analyses-sessions/` sans refaire la méthode à la main, et
pouvoir analyser une session à sa fin. Déclenchable **uniquement à la demande** : pas de
hook automatique.

## Ébauche

Un plugin `session-analysis` dans la marketplace locale, avec deux usages :

1. **Rapport global** (ex. `/session-analysis:report`)
   - interroge AgentsView et les transcripts avec la méthode du dernier rapport, sur les
     30 derniers jours (fenêtre par défaut de l'API), en global puis pour les 4 projets les
     plus actifs sur la période ;
   - écrit `docs/analyses-sessions/AAAA-MM-JJ.md` avec le même tableau d'indicateurs ;
   - ajoute une section *Évolution* qui compare chaque indicateur au rapport précédent ;
   - ne touche pas à `pistes-amelioration/` : il propose, on valide.
2. **Bilan de fin de session** (ex. `/session-analysis:session`)
   - analyse la session en cours sur quelques axes fixes : échecs d'outils et leur cause,
     refus (worktree, `git-guard`, permissions), allers-retours de plan, respect des
     consignes (IntelliJ MCP, build-brief), clarté du prompt de départ ;
   - répond dans la conversation, avec au plus quelques pistes concrètes.

## À trancher

- Où vit la méthode « iso » : dans le skill, ou dans un fichier versionné que le skill lit
  et que chaque rapport cite.
- Garder aussi les indicateurs bruts (JSON) à côté du rapport, pour comparer sans relire le
  Markdown.
- Le bilan de fin de session s'archive-t-il quelque part, ou reste-t-il dans la conversation.
- Dépendance à AgentsView : que faire s'il ne tourne pas (transcripts seuls ?).
