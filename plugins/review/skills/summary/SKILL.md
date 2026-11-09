---
name: summary
description: Résumer une PR GitHub de façon concise — ce qu'elle change fonctionnellement et les choix techniques qu'elle fait (avec leur raison quand elle est écrite quelque part), plus les points d'attention — sans la relire ni rien poster. À utiliser quand on demande de résumer, expliquer ou présenter une PR (« c'est quoi la PR 83 ? », « résume cette PR »).
argument-hint: "[numéro | recherche]"
allowed-tools: Bash(gpr list:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh issue view:*), Bash(git:*), mcp__claude_ai_Atlassian_Rovo__getJiraIssue
---

Arguments : `$ARGUMENTS`

But : comprendre une PR en une minute — ce qu'elle fait, comment, et ce qui mérite
l'attention — avant de la relire, de la merger ou d'en parler. Lecture seule : rien n'est
posté ni modifié, ce n'est pas une revue (pour ça : `/review:pr`, ou `/review:diff` sur sa
propre branche).

## 1. La PR

- Argument numérique (`83`, `#83`) ou URL de PR → celle-là ; texte → `gpr list <recherche>`
  (plugin `git-nav`), sinon `gh pr list --search "<recherche>" --state all` : un seul
  résultat → celui-là, plusieurs → demander laquelle (`AskUserQuestion`, header « PR »).
- Sans argument : la PR en contexte dans la conversation, sinon celle de la branche
  courante (`gh pr view`), sinon demander.
- `gh pr view <n> --json number,title,body,url,state,author,baseRefName,headRefName,isDraft,additions,deletions,changedFiles,commits,files`.
  PR fermée ou mergée : la résumer quand même, en le signalant dans l'en-tête.

## 2. Le contexte

- **Le diff** : `gh pr diff <n>`. Très gros diff (au-delà de ~3000 lignes) : partir de la
  liste des fichiers (`files`), lire en entier ceux qui portent la logique, survoler le
  reste (tests, fichiers générés, lockfiles, renommages).
- **Le ticket** : chercher la référence comme dans `${CLAUDE_SKILL_DIR}/../../ticket.md`
  (*Trouver la référence*, *Le lire*) — c'est lui qui dit le besoin fonctionnel. Aucun ou
  illisible : continuer sans, le dire en une ligne.
- **Les choix** : leur raison se trouve dans la description, les messages de commits, le
  ticket et ses commentaires. N'en inventer aucune : sans raison écrite, décrire le choix
  sans le justifier, ou le signaler comme point d'attention s'il surprend.

## 3. Le résumé

Rendu dans la conversation, dans la langue de la conversation, **court** : viser 15 à 25
lignes, chaque puce une phrase. Pas de liste de fichiers ni de paraphrase du diff
ligne par ligne : ce qui compte pour comprendre.

```
**#<n> <titre>** — <auteur>, <base> ← <tête>, +<a>/−<d> sur <f> fichiers[, brouillon | mergée | fermée]
Ticket : <clé ou #issue — titre> | pas de ticket trouvé

**Fonctionnel**
- <ce qui change pour l'utilisateur ou le système : comportement ajouté, modifié, retiré>
- <cas limites ou règles métier notables>

**Choix techniques**
- <choix> — <raison, avec sa source (description, commit, ticket)> | <choix> (raison non donnée)
- <nouvelle dépendance, migration, changement d'API ou de schéma, config…>

**Points d'attention** (seulement s'il y en a)
- <écart au ticket, effet de bord possible, rupture de compatibilité, zone non testée, partie à relire de près>
```

- **Fonctionnel** : 1 à 4 puces, du point de vue de qui utilise le produit ou appelle le
  code ; pour une PR purement technique (refactoring, outillage), le dire en une puce
  (« aucun changement de comportement attendu ») et passer aux choix.
- **Choix techniques** : 1 à 5 puces, les décisions qui structurent la PR (approche, endroit
  où vit le code, motif, dépendance, stockage), pas chaque détail d'implémentation.
- **Points d'attention** : constats factuels, sans jugement de style ; pas une revue (pas
  de suggestion de code). Rien de notable → omettre la section.
- Description de la PR vide ou trompeuse par rapport au diff : le dire en une ligne dans
  les points d'attention.
