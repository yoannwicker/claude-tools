---
name: board-auto
description: Rattrapage quotidien des actions manquées par les watchers GitHub (review-watch, tidy-watch) — une fois par jour, après le premier passage d'un watcher, gh-watch board --all --missed en fond et une seule notification « N actions manquées » dont le clic ouvre la liste interactive (herdr, sinon un terminal) — à activer ou désactiver (on/off), ou voir le dernier rattrapage
argument-hint: "[on | off]"
disable-model-invocation: true
allowed-tools: Bash(gh-watch set board_auto:*), Bash(gh-watch catchup:*), Bash(gh-watch status:*), Bash(command -v gh-watch)
---

Argument : `$ARGUMENTS`

Rattrapage quotidien (`board_auto` dans la config de gh-watch, off par défaut) : à la fin
du premier `poll` de la journée de l'un des watchers (`review-watch`, `tidy-watch`), une
seule fois par jour pour tous, `gh-watch board --all --missed --json` tourne en fond. S'il
reste des actions manquées (événement jamais vu, lancement en échec, notifiée sans session
lancée…), **une** notification « N actions manquées » ; son clic ouvre
`gh-watch board --all --missed -i` dans un workspace herdr s'il tourne, sinon dans un
terminal (réglage `terminal` du watcher). Rien n'est lancé sans choix dans la liste.

`gh-watch` absent du `PATH` (`command -v gh-watch`) : dire qu'il s'installe avec le plugin
(`./install.sh plugin gh-watch` depuis claude-tools, ou avec `review` / `git-tidy` qui en
dépendent) et s'arrêter.

## Avec `on` ou `off`

`gh-watch set board_auto on|off`, puis `gh-watch catchup` ; afficher les deux sorties
telles quelles, en quelques lignes.

## Sans argument

1. `gh-watch catchup` : afficher la sortie telle quelle (réglage, dernier rattrapage, manquées
   en attente depuis plus d'un jour ouvré avec la commande pour les lancer).
2. Demander (`AskUserQuestion`, header « Rattrapage ») : activer ou désactiver, l'état
   actuel en premier marqué « (actuel) ». Si le choix change le réglage :
   `gh-watch set board_auto on|off` et afficher la sortie en une ligne.

## Dans les deux cas

Le rattrapage n'a lieu que si le timer d'au moins un watcher tourne : si `gh-watch catchup`
le signale (« aucun timer de watcher actif »), rappeler `review-watch enable` ou
`tidy-watch enable` (ou `/review:pr-auto`, `/git-tidy:approved-auto`, qui le proposent).
