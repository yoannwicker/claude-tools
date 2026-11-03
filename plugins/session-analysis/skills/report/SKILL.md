---
name: report
description: Rapport d'analyse des sessions d'agents (Claude Code, Copilot…) sur les 30 derniers jours avec AgentsView, en global puis par projet — ce qui s'est amélioré ou dégradé, et des pistes d'amélioration
argument-hint: "[projet…] [--days N]"
disable-model-invocation: true
allowed-tools: Bash(agentsview-up:*), Bash(session-analysis-collect:*), Bash(session-analysis-feedback:*), Bash(agentsview:*), Bash(curl -s http://127.0.0.1:*)
---

Arguments : `$ARGUMENTS`

But : savoir **ce qui s'est amélioré et ce qui s'est dégradé** dans l'usage des agents, et
en tirer des **pistes d'amélioration**. Le rapport est brut et factuel : chaque constat
s'appuie sur des chiffres.

## 1. Consignes du projet

Avant tout, chercher dans les consignes du dépôt courant (`AGENTS.md`, `CLAUDE.md`, et les
docs qu'elles citent) où ranger les rapports, comment les nommer, et où trouver le rapport
précédent. Elles priment sur ce skill pour tout ce qui est propre au projet : emplacement,
format du fichier, conservation de `indicators.json` à côté du rapport, comparaison avec
les analyses précédentes, suite donnée aux pistes.
Sans consigne : rapport rendu dans la conversation, comparaison seulement si l'utilisateur
désigne un rapport précédent.

## 2. Collecter

```
session-analysis-collect report --out <scratchpad>/session-analysis-<date> [--days N] [--project P]…
```

- Lance AgentsView s'il ne tourne pas (`agentsview-up`). S'il n'est pas installé, le dire
  avec la commande d'installation donnée par l'erreur, et s'arrêter.
- **Période** : les 30 derniers jours (`--days N` si l'utilisateur en donne un autre).
- **Projets suivis** : les 4 premiers de la période en nombre de messages ; si des projets
  sont passés en argument, ceux-là seulement (`--project` par projet, nom tel
  qu'AgentsView l'affiche : `claude_tools`, pas `claude-tools`). Un nom inconnu fait
  échouer le script avec la liste des projets connus : la proposer.
- Résultat : `indicators.json` (le tableau d'indicateurs, global et par projet, mêmes clés à
  chaque rapport, dont `feedback` : les retours notés par `/session-analysis:feedback` sur
  la période), les réponses brutes de l'API (`global/`, `projects/<p>/`) et les
  compteurs des transcripts (`transcripts.json`).

Pour creuser un point : `agentsview session list|get|tool-calls|messages --json`,
`agentsview health <id> --json`, l'API `<url>/api/v1/analytics/<endpoint>?project=…`, ou le
transcript (`file_path` de `agentsview session list --include-source --json`). Le texte des
retours : `session-analysis-feedback list --days N --json [--project P]`.

## 3. Règles d'analyse

- **Vérifier une cause dans les transcripts avant de l'écrire.** L'extrait que
  `signal-sessions` donne pour une session est son premier message, pas l'appel qui a
  échoué : une session qui commence par `gh pr view` n'a pas forcément échoué sur `gh`.
- Une commande se compte quand elle est appelée, pas quand son nom apparaît dans un chemin
  ou un argument (`gpr-record` n'est pas `gpr`). `session-analysis-collect` le fait déjà ;
  le refaire à la main de la même façon.
- AgentsView ne note (A à F) qu'une partie des sessions : donner le nombre de sessions
  notées à côté des notes, et des taux plutôt que des comptes quand les tailles diffèrent.
- Petit échantillon (moins de 5 sessions notées) : écrire « trop peu pour conclure ».
- Les transcripts ne couvrent que Claude Code ; pour les autres agents, seulement AgentsView.
- Ne rien affirmer sans chiffre ; corriger dans le rapport une erreur trouvée en route, et
  la signaler.

## 4. Rapport

En français, sections dans cet ordre :

1. **Titre et période** : `# Analyse des sessions — AAAA-MM-JJ`, période, projets suivis
   et comment ils ont été choisis (les 4 plus gros, ou demandés).
2. **Méthode** : sources (AgentsView, transcripts), période, sélection des projets, limites.
3. **Vue d'ensemble** : tableau des indicateurs globaux de `indicators.json` (sessions par
   agent, jours actifs, messages, tokens, médiane/p90 de messages, score de santé, notes,
   issues, sessions avec échec d'outil, compactions, boucles en échec, part de Bash, Bash
   de lecture, MCP IntelliJ, erreurs d'outils par type, `ExitPlanMode` appels/repris,
   `AskUserQuestion`, skills, modèles), puis 2 ou 3 faits marquants.
4. **Vue d'ensemble par projet** : un tableau, une colonne par projet suivi (sessions,
   messages et part, tokens, jours actifs, médiane/p90, sessions notées, score, notes, taux
   d'échec, compactions, skills les plus utilisés, plus longue session), puis une ligne de
   lecture par projet.
5. **Évolution** : ce qui s'est **amélioré**, ce qui s'est **dégradé**, ce qui est stable,
   indicateur par indicateur, par rapport au rapport précédent (voir 1). Sans rapport
   précédent, le dire en une ligne.
6. **Constats** : un sous-titre par problème, avec ses chiffres et un tableau par projet
   suivi dont la dernière colonne est **Concerné** (oui / non / en partie / trop peu pour
   conclure).
7. **Retours** : les retours notés sur la période (`feedback` dans `indicators.json`, texte
   avec `session-analysis-feedback list`), regroupés par cible avec leurs avis et leurs
   angles. Distinguer les constats de Claude confirmés par l'utilisateur (`d'accord`,
   `nuancé`), ceux qu'il conteste (`pas d'accord` : un retour sur l'analyse elle-même) et
   les retours de l'utilisateur. Les rapprocher des constats chiffrés : un retour négatif
   qui recoupe un indicateur dégradé pèse plus, un retour sans chiffre pour l'appuyer reste
   un ressenti, à dire. Aucun retour : une ligne.
8. **Synthèse par projet** : matrice constats × projets.
9. **Pistes d'amélioration** : numérotées, concrètes (quoi changer, où : consigne, hook,
   skill, plugin, façon de prompter), chacune avec les projets visés, les constats ou
   retours d'où elle vient, et l'indicateur qui dira au prochain rapport si elle a
   marché.

Les pistes sont des propositions : n'en faire des tâches, des fichiers ou des
modifications que si l'utilisateur ou les consignes du projet le demandent.

Terminer dans la conversation par un résumé court : ce qui s'est amélioré, ce qui s'est
dégradé, les 3 pistes les plus utiles, et où est le rapport s'il a été écrit.
