---
name: session
description: Bilan de la session Claude Code en cours avec AgentsView — note, échecs et refus, allers-retours, qualité des prompts — avec des pistes d'amélioration et des conseils
argument-hint: "[identifiant de session]"
disable-model-invocation: true
allowed-tools: Bash(agentsview-up:*), Bash(session-analysis-collect:*), Bash(session-analysis-feedback:*), Bash(agentsview:*)
---

Arguments : `$ARGUMENTS`

Session en cours : `${CLAUDE_SESSION_ID}`.

But : un rapport court sur une seule session (la session en cours, ou celle passée en
argument) pour en tirer des pistes d'amélioration et des conseils. Rendu dans la
conversation, rien n'est écrit dans le dépôt.

## 1. Collecter

```
session-analysis-collect session --out <scratchpad>/session-analysis-session <id>
```

`<id>` : l'argument s'il y en a un, sinon la session en cours ci-dessus. Si l'identifiant
n'a pas été remplacé (le texte `${…}` reste tel quel), lancer la commande sans `<id>` : le
script prend la session la plus récente du dossier courant.

- Lance AgentsView s'il ne tourne pas, resynchronise la session, puis écrit
  `session.json` (métadonnées, signaux de qualité), `health.json` (note, score et
  pénalités) et `transcript.json` (outils appelés, Bash de lecture, MCP IntelliJ, erreurs
  par type, modèles).
- AgentsView n'est pas installé : le dire avec la commande donnée par l'erreur, s'arrêter.

Pour le détail : `agentsview session tool-calls <id> --json`, `agentsview session messages
<id> --json`, et le contexte de cette conversation, qui reste la meilleure source pour une
session en cours.

## 2. Axes d'analyse

- **Note** : note et score de santé, pénalités (`health_penalties`) et ce qui les explique.
  Une session en cours a souvent une issue `unknown` et des signaux en attente
  (`signals_pending_since`) : le préciser.
- **Volume** : durée, messages, tokens, pic de contexte, compactions.
- **Échecs et refus** : erreurs d'outils par type, avec leur cause réelle vérifiée dans la
  conversation (refus d'isolation worktree, hooks, classifieur du mode auto, refus de
  l'utilisateur, erreurs de commande) ; tours perdus.
- **Allers-retours** : plans refusés, questions posées, corrections demandées par
  l'utilisateur, travail refait.
- **Prompts** : signaux de qualité (prompts courts, départ non structuré, critère de succès
  ou vérification manquants, prompt répété) et ce qui aurait évité des tours.
- **Consignes** : respect des consignes chargées dans la session (`CLAUDE.md`, `AGENTS.md`,
  consignes des plugins : MCP IntelliJ, build-brief…) — usages de Bash à la place d'un outil
  prévu, étapes sautées.

## 3. Rapport

Court, en français :

1. Une ligne d'en-tête : projet, note (score), issue, durée, messages.
2. Un petit tableau des chiffres clés.
3. **Ce qui a bien marché** et **ce qui a coûté** (2 à 4 points chacun, chiffrés).
4. **Pistes d'amélioration** : pour la config (consigne, hook, skill, plugin) et pour la
   façon de travailler (prompt, découpage, vérification). 3 au plus, concrètes.
5. **Conseil pour la suite de la session** s'il y en a un (ex. repartir d'une session
   neuve, préciser le critère de succès).
6. **Retours** : ceux déjà notés pour cette session
   (`session-analysis-feedback list --session <id>`), et s'il y a matière (échec, refus,
   hook ou skill qui a gêné ou aidé) proposer en une ligne `/session-analysis:feedback`.
