---
name: approved-auto
description: Mode auto des PR approuvées — lancer d'office /git-tidy:ready (commits au propre, rebase, description et ticket, puis ticket JIRA passé en validation et message Slack pour le testeur) quand une de mes PR a ses approbations (2 par défaut) — à activer ou désactiver sur le dépôt courant (on/off) ou en choisissant parmi les dépôts connus ; approbations, statut JIRA et environnement de test réglables par dépôt
argument-hint: "[on | off | interval <minutes> | approvals <n|default> | status <statut|default> | env <texte|default> | ready <statuts|default>]"
disable-model-invocation: true
allowed-tools: Bash(tidy-watch:*), Bash(command -v tidy-watch)
---

Argument : `$ARGUMENTS`

`tidy-watch` (dans le `bin/` du plugin, timer systemd, toutes les 5 min par défaut) : une
de mes PR ouvertes, hors brouillon, a au moins **N approbations** (dernier avis de chaque
relecteur, 2 par défaut, réglable par dépôt), aucun changement demandé, et aucun fil de
review en attente de ma réponse (non résolu, dernier message d'un autre : elle attend).
Il lance alors `/git-tidy:ready <n>` dans le worktree de la branche : commits, rebase,
description et ticket, puis, la PR étant approuvée, passage du ticket JIRA au statut de
validation et message Slack à copier pour le testeur (tickets, PR de la pile,
environnement de test). Une PR n'est relancée que pour une nouvelle série d'approbations
(après qu'elles ont été écartées), pas pour une approbation de plus ni pour un push.

Par dépôt : **auto** (session lancée d'office : worktree et pane herdr s'il tourne, sinon
analyse en fond `--prepare` puis notification dont le clic reprend la session),
**notify** (notification, son clic lance la session) ou **off** (défaut des dépôts non
listés). Rien n'est réécrit, poussé ni publié sans validation dans la session.

`tidy-watch` absent du `PATH` (`command -v tidy-watch`) : dire qu'il faut l'installer avec
le plugin (`./install.sh plugin git-tidy` depuis claude-tools : lien et unités systemd) et
s'arrêter.

## Avec `interval [<minutes>]`

Fréquence du scan : `tidy-watch interval [<minutes>]` (5 par défaut ; sans nombre, affiche
la valeur). Afficher la sortie en une ligne.

## Avec `approvals [<n> | default]`

Approbations attendues sur le dépôt courant : `tidy-watch approvals . [<n> | default]`
(`default` : revenir à la valeur commune, 2 sauf `tidy-watch default --approvals <n>` ;
sans valeur : affiche). Afficher la sortie en une ligne.

## Avec `status [<statut> | default]`, `env [<texte> | default]` ou `ready [<statuts> | default]`

Réglages de `/git-tidy:ready` (et de la colonne JIRA de `/gh-watch:board`) pour le dépôt
courant :
- `status` → `tidy-watch set . validation_status [<statut> | default]` : statut JIRA où passe
  le ticket une fois la PR approuvée (`En validation` par défaut) ;
- `env` → `tidy-watch set . test_env [<texte> | default]` : environnement de test cité dans
  le message Slack (texte ou URL ; `{pr}`, `{branch}`, `{ticket}` remplacés ; sans réglage :
  déploiements GitHub de la branche, sinon demandé) ;
- `ready` → `tidy-watch set . jira_ready [<statuts> | default]` : statuts JIRA qui comptent
  comme « validé » (séparés par des virgules ; ✓ dans la colonne JIRA de `/gh-watch:board`).

Sans valeur, la commande affiche le réglage et sa provenance. Afficher la sortie en une
ligne.

## Avec `on` ou `off`

Dépôt courant : `tidy-watch auto . on|off`. `off` remet le mode des dépôts non listés (off
par défaut) et garde les autres réglages du dépôt. Afficher la sortie en une ligne.

## Sans argument

1. `tidy-watch repos --json` : dépôts configurés et clones GitHub des espaces de travail
   de `cl` (`repo`, `path`, `approved`, `approvals`, `validation_status`, `test_env`).
2. Demander (`AskUserQuestion`, `multiSelect`, header « Auto ») quels dépôts ont `approved`
   en auto : une option par dépôt, ceux déjà en auto en premier et marqués « (actif) »
   avec leur nombre d'approbations, le dépôt courant ensuite. Au-delà de 4 options : les 3
   premières plus « Autres… » ; dans ce cas, montrer d'abord la liste numérotée complète
   et accepter des numéros ou noms en texte libre.
3. Pour chaque dépôt dont l'état change : `tidy-watch auto <repo> on|off`.
4. Récapitulatif : `tidy-watch status` et, pour les dépôts en auto, `validation_status` et
   `test_env` (de `repos --json`) ; rappeler `/git-tidy:approved-auto approvals <n>`,
   `status <statut>`, `env <texte>` et `ready <statuts>` pour les régler.

## Dans les deux cas

Si `status` (ou la sortie de `auto`) dit la surveillance arrêtée et qu'au moins un dépôt est
en auto, proposer `tidy-watch enable` (`AskUserQuestion`, header « Surveillance ») et le
lancer sur accord : il enregistre ce qui est déjà en attente sans rien lancer, puis active
le timer. Le profil Claude lancé par `tidy-watch` (réglage `claude` de sa config) doit
activer le plugin `git-tidy`.
