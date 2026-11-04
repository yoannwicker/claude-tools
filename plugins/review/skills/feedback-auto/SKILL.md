---
name: feedback-auto
description: Mode auto des retours de revue — lancer le plan de traitement (/review:feedback) au retour de revue reçu sur mes PR créées — à activer ou désactiver sur le dépôt courant (on/off) ou en choisissant parmi les dépôts connus
argument-hint: "[on | off | interval <minutes>]"
disable-model-invocation: true
allowed-tools: Bash(review-watch:*)
---

Arguments : `$ARGUMENTS`

Lire `${CLAUDE_SKILL_DIR}/../../auto.md` et le suivre avec `<kind>` = `feedback`.
