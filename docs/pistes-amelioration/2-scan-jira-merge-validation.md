# Scan JIRA : ce qui peut être mergé, ce qui attend un retour

- **Statut** : proposée
- **Origine** : idée (2026-11-05)

## Constat

Après la validation par deux devs, `/git-tidy:approved-auto` passe le ticket « En
validation » et rédige le message pour le testeur. La suite se joue dans JIRA (ticket
validé par le testeur, ou renvoyé avec des retours) et rien ne la surveille : la PR reste
ouverte jusqu'à ce qu'on y pense.

## Proposition

Un scan des tickets liés à mes PR ouvertes, selon leur statut JIRA :

- ticket validé par le testeur (statut à régler par dépôt) → PR prête à merger : proposer
  le merge, précédé d'un rebase sur `main` et de `/git-tidy:ready` (c'est la piste
  `/git-tidy:merge-auto` déjà évoquée : merge seulement après accord) ;
- ticket renvoyé (retour en cours, commentaires du testeur) → retours à traiter : les
  montrer, avec les commentaires sur la PR.

## À trancher

- L'affichage du statut JIRA des PR approuvées est l'étape 6 de
  [gh-watch : tableau de bord des PR](1-gh-watch-board.md) : cette piste garde le merge et
  le traitement des retours du testeur, et peut partir de ce tableau.

- Accès JIRA depuis un timer : le MCP Atlassian n'existe que dans une session Claude ;
  token d'API JIRA lu par le watcher (REST), ou scan seulement à la demande dans une
  session (skill), sans timer.
- Statuts JIRA à régler par dépôt (« validé », « retour ») dans
  `~/.config/claude-tools/git-tidy.json`, comme `validation_status`.
- Lien ticket ↔ PR : clé dans la branche, le titre ou la description (comme `pr-sync`).
