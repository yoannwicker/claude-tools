---
name: feedback
description: Retour sur l'usage de Claude dans la session en cours — Claude analyse selon des angles fixes les skills, plugins, hooks, consignes et MCP qui ont servi (ou auraient dû), l'utilisateur donne son avis sur chaque constat et ajoute les siens ; journal repris par /session-analysis:report
argument-hint: "[retour en texte libre]"
disable-model-invocation: true
allowed-tools: Bash(session-analysis-feedback:*), Bash(session-analysis-collect:*), Bash(agentsview-up:*), Bash(agentsview:*)
---

Arguments : `$ARGUMENTS`

Session en cours : `${CLAUDE_SESSION_ID}`.

But : un retour sur **la config** (skills, plugins, hooks, consignes, MCP) telle qu'elle a
servi dans cette session, pour la faire évoluer. Claude fait l'essentiel : il analyse la
session selon les angles ci-dessous et en tire des constats. L'utilisateur donne ensuite
son avis sur chacun, et ajoute ce que Claude n'a pas vu. Tout va dans un journal, repris par
`/session-analysis:report`. Ce n'est pas le bilan de la session (`/session-analysis:session`
note la session, ses prompts, son volume) : ici on juge les éléments de la config.

## 1. Rassembler les faits

- La conversation : skills et commandes lancés, hooks déclenchés (refus, messages
  injectés), consignes chargées, plugins et serveurs MCP utilisés ou en échec de connexion,
  outils en erreur, corrections et allers-retours avec l'utilisateur.
- Les compteurs de la session, toujours :
  `session-analysis-collect session --out <scratchpad>/session-feedback ${CLAUDE_SESSION_ID}`
  — le script lance AgentsView s'il ne tourne pas (`agentsview-up`) et resynchronise la
  session ; `transcript.json` donne les erreurs d'outils par type, dont les refus de hook
  `[nom]`, et les appels par outil. Identifiant non remplacé (`${…}` tel quel) : sans
  identifiant. AgentsView pas installé ou qui ne démarre pas : le dire en une ligne avec la
  commande donnée par l'erreur, puis continuer avec la seule conversation.

## 2. Analyser, angle par angle

Pour chaque élément de la config qui a servi, ou qui aurait dû servir :

1. **Déclenchement** : utilisé quand il fallait ? Skill lancé à bon escient, ou tâche faite
   à la main alors qu'un skill ou une commande existe ; hook qui a refusé un appel
   légitime, ou qui ne s'est pas déclenché quand il aurait dû.
2. **Résultat** : a-t-il fait ce qu'on attendait du premier coup ? Étapes suivies, sortie
   juste ; ou corrections de l'utilisateur, travail refait, étape sautée.
3. **Friction** : ce qu'il a coûté — refus, questions en trop ou inutiles, demandes de
   permission, étapes longues, tours perdus.
4. **Consignes** : suivies ou contournées ; contradictoires entre elles ou avec le code ;
   obsolètes (outil, fichier ou option qui n'existe plus).
5. **Outillage** : MCP et outils externes — indisponible, en erreur, mauvais outil choisi,
   repli sur Bash.
6. **Manques** : ce qui mériterait un skill, un hook, une consigne ou une option (geste
   répété, information recherchée à chaque fois, vérification oubliée).

Un constat :

- s'appuie sur un fait précis de la session (« le hook build-brief a refusé 2 fois
  `./gradlew --version` »), jamais sur une impression ;
- porte sur une **cible** : type (`skill`, `plugin`, `hook`, `consigne`, `mcp`, `session`,
  `autre`) et nom tel qu'on l'appelle (`git-nav:pr`, `build-brief`, `intellij`,
  `AGENTS.md`…) ;
- a un **avis** : `positif` (à garder), `négatif` (à corriger) ou `suggestion` (à ajouter
  ou changer) ;
- se dit en une ou deux phrases : le fait, puis ce qu'il a coûté ou apporté, ou ce qu'il
  faudrait changer.

Garder les 6 constats les plus utiles au plus, les négatifs et suggestions d'abord ; un
élément qui a simplement marché ne vaut un constat positif que s'il a évité un problème
réel. Session sans rien de notable : le dire, et passer à l'étape 4.

## 3. L'avis de l'utilisateur sur chaque constat

Présenter les constats (tableau : n°, angle, cible, avis, constat), puis `AskUserQuestion`,
une question par constat (4 par appel, plusieurs appels si besoin), header `Constat <n>` :

- **D'accord** ;
- **Nuancé** — l'utilisateur précise (champ libre ou notes) ;
- **Pas d'accord** — l'utilisateur dit pourquoi s'il le veut ; le constat est gardé, c'est
  un retour sur l'analyse elle-même ;
- **Écarter** — hors sujet, il n'est pas noté.

## 4. Les retours de l'utilisateur

Puis demander s'il a d'autres retours (`AskUserQuestion`, header « Retours ») :
**Non** / **Oui** (il les écrit). Un texte passé en argument en est un d'office. Les
rattacher chacun à une cible, un avis et, si possible, un angle ; les reformuler court
sans en changer le sens, et les faire confirmer.

## 5. Écrire

Une ligne par constat gardé et par retour de l'utilisateur :

```
session-analysis-feedback add --session ${CLAUDE_SESSION_ID} --source claude \
  --angle <angle> --target-type <type> --target <cible> --verdict <avis> \
  --text "<constat>" --user-opinion <d'accord|nuancé|pas d'accord> [--comment "<précision>"]
session-analysis-feedback add --session ${CLAUDE_SESSION_ID} --source utilisateur \
  [--angle <angle>] --target-type <type> --target <cible> --verdict <avis> --text "<retour>"
```

Angles : `déclenchement`, `résultat`, `friction`, `consignes`, `outillage`, `manques`.
Le projet est déduit de la session ou du dépôt courant (`--project <nom>` le force) ; le
journal est celui de `.session-analysis.json` s'il y en a un, sinon le journal par défaut :
le script s'en charge.

Terminer par ce qui a été noté (la sortie du script) et la commande pour relire le
journal : `session-analysis-feedback list [--days N] [--project P]`. Ne rien changer dans le
dépôt, ne créer ni piste ni tâche : le prochain rapport reprend les retours.
