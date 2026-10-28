# Le ticket (commun à `/review:diff` et `/review:pr`)

But : donner à l'agent ce que le ticket demande, pour qu'il vérifie que le diff y
correspond — et que tout écart (périmètre ajouté ou retiré, changement de direction) est
justifié quelque part.

## Trouver la référence

Chercher, dans l'ordre : le nom de la branche, le titre et la description de la PR, les
messages des commits relus.

- Clé JIRA (`ABC-123`, motif `[A-Z][A-Z0-9]+-[0-9]+`), lien vers un ticket ;
- issue GitHub : `#123` dans un `closes`/`fixes`/`refs`, lien vers une issue.

Plusieurs tickets → tous, le principal (celui de la branche) en premier. Aucun → le dire
en une ligne (« pas de ticket trouvé ») et continuer sans.

## Le lire

- JIRA : outil `getJiraIssue` du MCP Atlassian, **avec ses commentaires** ; si c'est une
  sous-tâche, lire aussi l'US parente (description, critères d'acceptation).
- Issue GitHub : `gh issue view <n> --comments`.

Ticket introuvable ou outil absent (pas de MCP, pas d'accès) : le dire en une ligne et
continuer sans.

## Le passer à l'agent

Dans le message qui lance `review:reviewer` : clé, titre, description, critères
d'acceptation, US parente, et les commentaires (auteur, date, texte) — en entier, pas un
résumé : c'est souvent dans un commentaire qu'un choix a été fait. Pour `/review:diff`,
ajouter la description de la PR de la branche s'il y en a une
(`gh pr view --json body`).
