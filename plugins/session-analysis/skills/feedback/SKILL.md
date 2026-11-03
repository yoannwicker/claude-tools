---
name: feedback
description: Noter en fin de session un retour sur l'usage de Claude — skill, plugin, hook, consigne, MCP ou la session elle-même (positif, négatif, suggestion) — dans un journal personnel repris par /session-analysis:report
argument-hint: "[retour en texte libre]"
disable-model-invocation: true
allowed-tools: Bash(session-analysis-feedback:*)
---

Arguments : `$ARGUMENTS`

Session en cours : `${CLAUDE_SESSION_ID}`.

But : garder le **ressenti** de l'utilisateur sur ce qui a servi pendant la session — ce
que les chiffres d'AgentsView ne disent pas (« ce skill m'a fait perdre du temps », « ce
hook m'a évité une erreur », « il faudrait que /pr fasse X »). Les retours vont dans un
journal personnel (par défaut hors du dépôt ; un `.session-analysis.json` peut le placer
ailleurs, le script s'en charge) ; `/session-analysis:report` les reprend.

## 1. Repérer ce qui a servi

Relire la conversation : skills et commandes lancés, hooks déclenchés (refus, messages
injectés), consignes chargées et suivies ou contournées, plugins et serveurs MCP utilisés
(ou en échec de connexion), refus et échecs d'outils, allers-retours avec l'utilisateur.

## 2. Proposer les retours

- L'utilisateur a donné un texte : en partir. Le rattacher à sa cible, le reformuler court
  et factuel sans en changer le sens ; s'il parle de plusieurs choses, un retour par cible.
- Sans texte : proposer 1 à 3 retours candidats tirés de la session, chacun appuyé sur un
  fait précis (« le hook build-brief a refusé 2 fois `./gradlew --version` »). Rien de
  notable : le dire et demander à l'utilisateur ce qu'il veut noter.

Chaque retour a :

- **type de cible** : `skill`, `plugin`, `hook`, `consigne`, `mcp`, `session` ou `autre` ;
- **cible** : le nom tel qu'on l'appelle (`git-nav:pr`, `build-brief`, `intellij`,
  `AGENTS.md`…) ; pour `session`, le sujet en deux ou trois mots ;
- **avis** : `positif`, `négatif` ou `suggestion` ;
- **texte** : une ou deux phrases, le fait et ce qu'il a coûté ou apporté ; pour une
  suggestion, ce qu'il faudrait changer.

## 3. Valider avant d'écrire

Faire valider par `AskUserQuestion` (une question par retour, au plus 4 : garder / modifier
/ écarter, le retour complet dans la question). Rien n'est écrit sans accord ; un retour à
modifier est corrigé puis revalidé.

## 4. Écrire

Pour chaque retour gardé :

```
session-analysis-feedback add --session ${CLAUDE_SESSION_ID} --target-type <type> --target <cible> --verdict <avis> --text "<texte>"
```

Le projet est déduit de la session (AgentsView) ou du dépôt courant ; `--project <nom>` le
force (nom AgentsView : `claude_tools`). Si l'identifiant de session n'a pas été remplacé
(le texte `${…}` reste tel quel), le script l'ignore.

Terminer par ce qui a été noté (la sortie du script) et la commande pour relire le
journal : `session-analysis-feedback list [--days N] [--project P]`. Ne rien écrire dans le
dépôt, ne créer ni piste ni tâche : les retours sont repris par le prochain rapport.
