---
name: pr-auto
description: Mode auto des demandes de review — lancer ces revues d'office (/review:pr) à la demande de review — à activer ou désactiver sur le dépôt courant, un dépôt, tous ceux d'un propriétaire (owner/*) ou tous (*) (on/off) ou en choisissant parmi les dépôts connus
argument-hint: "[on | off [<owner/repo> | <owner>/* | *] | interval <minutes>]"
disable-model-invocation: true
allowed-tools: Bash(review-watch:*)
---

Arguments : `$ARGUMENTS`

Lire `${CLAUDE_SKILL_DIR}/../../auto.md` et le suivre avec `<kind>` = `review_requested`.
