# gh-watch : tableau de bord des PR (`board`), actions manquées et rattrapage

- **Statut** : en cours (étapes 1 à 4 faites, liste interactive comprise)
- **Origine** : idée (2026-11-05), fusion de
  [review : faire le point sur mes PR](2-review-point-mes-pr.md),
  [gh-watch : vue des PR en cours](3-gh-watch-vue-pr.md),
  [scan GitHub : déclencher la bonne action](2-scan-github-actions-pr.md) et
  [gh-watch : rattrapage quotidien](2-gh-watch-rattrapage.md)

## Constat

Rien ne donne d'un coup l'état de mes PR ouvertes et des relectures qu'on attend de moi :
il faut aller voir GitHub, dépôt par dépôt. Les watchers réagissent à des événements et
des demandes leur échappent (revue que je me demande moi-même, notification lue à la main,
lancement en échec que `dispatch` marque traité quand même). Quatre pistes calculaient
chacune de leur côté le même état des PR ; `review-watch` (`feedback_events`) et
`tidy-watch` (`approved_events`) le calculent déjà, chacun avec sa requête.

## Proposition

Un seul calcul de l'état des PR, dans `gh-watch` (plugin de base, dont `review` et
`git-tidy` dépendent, seul à voir tous les watchers), et trois usages par-dessus : le point
(général ou sur un dépôt), les actions manquées des dépôts en `auto`, et leur rattrapage
automatique.

### Répartition entre plugins

| Plugin | Apporte |
|---|---|
| `gh-watch` | le calcul (`lib/board.py`), `gh-watch board`, `gh-watch launch`, `/gh-watch:board`, `/gh-watch:board-auto`, l'état des lignes écartées hors watcher |
| `review` (`review-watch`) | déclare les états qu'il prend en charge : `to_review`, `re_requested` → événement `review` (`/review:pr`) ; `feedback` → événement `feedback` (`/review:feedback`) |
| `git-tidy` (`tidy-watch`) | déclare `approved` → événement `approved` (`/git-tidy:ready`) ; le seuil `approvals` par dépôt (déjà exposé par `status --json`) ; l'action suggérée `/git-tidy:pr-sync` pour `behind` (sans événement) ; plus tard, les statuts JIRA reconnus |

Plugin absent : l'état s'affiche quand même, sans action ni suivi (seuil d'approbations : 2).
Pas de `/review:status`. `pr-comments` (mod tiers, dépôt courant) reste tel quel.

### États

Le tableau ne lit que l'état actuel de GitHub, jamais les notifications.

**Mes PR** (`author:@me`), un état par PR :

| État | Règle | Ancienneté depuis | Action suggérée |
|---|---|---|---|
| `draft` | brouillon | création | — |
| `unrequested` (à faire relire) | aucun relecteur demandé ni aucune review | passage en prêt | demander des relecteurs |
| `in_review` | relecteurs demandés, pas de review des autres à traiter | plus ancienne demande en attente (et qui) | relancer |
| `feedback` (retours à traiter) | changements demandés, fil non résolu dont le dernier message n'est pas de moi, ou message de review qui demande une réponse (étape 4) | premier retour sans réponse | `/review:feedback` |
| `waiting_reviewer` | fils non résolus, dernier message de moi | ma dernière réponse | relancer |
| `approved` (à préparer) | ≥ `approvals` approbations, aucun changement demandé, aucun retour en attente de moi | N-ième approbation | `/git-tidy:ready` |
| `prepared` (en validation) | `approved` et déjà traitée par `tidy-watch` depuis (ou statut JIRA de validation, étape 6) | traitement | — |

Alertes cumulables avec l'état : CI en échec, en retard sur sa base (`behind` →
`/git-tidy:pr-sync`), conflit.

**PR des autres** :

| État | Règle | Ancienneté depuis | Action suggérée |
|---|---|---|---|
| `to_review` | `review-requested:@me` (moi ou une de mes équipes : « via @équipe »), jamais relue | dernière demande qui me vise | `/review:pr` |
| `re_requested` | `review-requested:@me` et une review de moi avant la dernière demande (GitHub retire le relecteur à sa review : réapparaître, c'est être redemandé, par le bouton ou à la main) | dernière demande | `/review:pr` |
| `reviewed` | `reviewed-by:@me`, plus demandé : en attente de l'auteur, ou « l'auteur a répondu (N fils) » | ma review / sa réponse | — |
| `mentioned` | `mentions:@me`, sans demande | mention | — |
| `open_unrequested` | seulement si `others = open` pour le dépôt : PR ouverte d'un autre, hors brouillon, sans toutes ses approbations, pas relue par moi | création | — |

Tri par ancienneté dans chaque groupe ; ⚠ au-delà de `stale_days` (2 par défaut).
`open_unrequested` et `mentioned` ne sont jamais « manqués » (aucun watcher ne les gère).

### Commandes

| Commande | Effet |
|---|---|
| `gh-watch board [<owner/repo>\|--all] [--full] [--json]` | le point : dépôt courant (tous hors d'un clone), un dépôt, ou tous (`--all` : ce sur quoi j'ai à agir, dépôts filtrés par `set board` ; `--full` : tout) |
| `… --auto` | lignes prises en charge par un watcher (`auto` ou `notify`), avec leur mode et leur suivi : session lancée, ouverte, prête à reprendre, en échec, manquée |
| `… --missed` | les manquées seulement, dépôts en `auto` ou `notify` |
| `… --missed --launch` | les lance toutes (`<watcher> launch`) ; `--launch` sans `--missed` : refusé |
| `… --skipped` | montre aussi les lignes écartées |
| `gh-watch launch <repo#n> [état]` | lance une ligne par le watcher qui la gère |
| `gh-watch skip <repo#n> [--until-closed]` / `unskip <repo#n>` | écarter / réintégrer |
| `/gh-watch:board [<owner/repo>\|--all] [--auto\|--missed] [--launch]` | la même vue dans Claude ; avec `--missed`, sélection multiple des lignes à lancer ou écarter (non cochée : rien d'enregistré, revient au prochain point) ; `--launch` : tout sans demander |
| `/gh-watch:board-auto on\|off` | rattrapage automatique (étape 5) |

**Manquée** : un watcher gère l'état, le dépôt est en `auto` ou `notify` pour cet
événement (une notification a pu être perdue), et le watcher ne l'a pas traitée — date retenue
(`state[kind]`) antérieure à l'événement, aucune session en cours — ou son dernier
déclenchement est un `échec`. La date de l'événement est celle de `poll` : demande de
revue (`review`), dernière review d'un autre (`feedback`), N-ième approbation (`approved`).

**Écarter** : au choix à chaque fois. `skip` seul : jusqu'au prochain événement GitHub sur
cet état (nouvelle demande, nouvelle review…). État géré par un
watcher → `<watcher> skip` (`state[kind] = date de l'événement`, historique « refusé »),
pour que `poll` ne le relance pas non plus ; sinon état propre de gh-watch
(`~/.local/state/claude-tools/gh-watch/state.json`). `--until-closed` : toute la PR,
jusqu'à sa fermeture. Les lignes écartées sont comptées en bas du tableau.

**Réglages** (`~/.config/claude-tools/gh-watch.json`) : `others` par dépôt
(`requested` par défaut, ou `open`), `stale_days` (jours ouvrés, week-ends exclus ; 2 par
défaut, choix arbitraire : une relecture attendue sous un ou deux jours ouvrés),
`board_auto` (étape 5).

## Plan

Chaque étape est un commit, doc comprise (CLAUDE-CODE.md, section `gh-watch` ; README.md
si l'arborescence change).

1. **Calcul et point, lecture seule.**
   - `plugins/gh-watch/lib/board.py` (à côté de `watchlib.py`, déjà long) : requêtes
     GraphQL (`author:@me`, `review-requested:@me`, `reviewed-by:@me`, `mentions:@me`,
     restreintes par `repo:` si un dépôt est donné ; `first: 50`, reviews, `reviewThreads`,
     `timelineItems(REVIEW_REQUESTED_EVENT)`, `statusCheckRollup`, `mergeStateStatus`) ;
     `classify(pr, login, approvals)` pure, qui rend l'état, les alertes, la date de
     l'événement et l'ancienneté.
   - `gh-watch board [dépôt] [--json]` : groupes, tri, ⚠, action suggérée (skill du
     watcher déclaré, sinon texte), seuil `approvals` lu dans `status --json` de
     `tidy-watch`.
   - `/gh-watch:board [dépôt]` : tableaux par groupe, lecture seule.
   - Tests : `plugins/gh-watch/tests/board.test.py` (fixtures JSON de PR → états, sans
     réseau) ; `gh-watch.test.sh` étendu (faux `gh` qui rend les fixtures).
2. **Suivi auto et manqués.**
   - `watchlib.configure(board={état: kind})` ; `status_data` expose `board` et les dates
     traitées (`handled[kind][repo#n]`).
   - `gh-watch board --auto`, `--missed` : croisement avec modes,
     dates traitées, sessions et dernier déclenchement.
   - `review-watch`, `tidy-watch` : déclaration `board=…`.
3. **Actions.**
   - `watchlib` : sous-commande commune `skip <repo#n> <kind> --at <date>`.
   - `gh-watch launch`, `board --missed --launch`, `skip|unskip` (état gh-watch pour
     les états sans watcher, `--until-closed`), `--skipped`.
   - `/gh-watch:board --missed` : sélection (`AskUserQuestion`, 16 lignes au plus par
     tour), lancer / écarter ; `--launch`.
4. **Un seul calcul partout.** `review-watch` (`feedback_events`) et `tidy-watch`
   (`approved_events`) passent par `board.classify`, pour que le tableau et `poll` ne
   divergent jamais. `review_events` garde les notifications (déclencheur rapide) ; le
   tableau couvre ce qu'elles ratent.
5. **Rattrapage automatique.** `/gh-watch:board-auto on|off` (`board_auto` dans la config
   de gh-watch) : à la fin du premier `poll` de la journée (verrou du watcher relâché),
   watchlib lance en détaché `gh-watch board --missed --json` ; s'il y a des lignes, **une**
   notification « N actions manquées » dont le clic ouvre un terminal sur
   `/gh-watch:board --missed`. `gh-watch status` / `/gh-watch:auto-status` : dernier rattrapage
   et manquées qui attendent depuis plus d'un jour (« ce qui cloche »).
6. **JIRA, dans le skill seulement** (MCP Atlassian) : statut du ticket lié (clé dans la
   branche, le titre ou la description, comme `pr-sync`) pour `prepared` et une colonne
   « JIRA » ; statuts reconnus réglés par dépôt dans `git-tidy.json` (comme
   `validation_status`). Le merge après validation reste la piste
   [scan JIRA](2-scan-jira-merge-validation.md).

## Décisions

- `skip` seul : jusqu'au prochain événement ; `--until-closed` : jusqu'à la fermeture de
  la PR (2026-11-05).
- `stale_days` en jours ouvrés, 2 par défaut (2026-11-05).
- `--missed` inclut les dépôts en `notify`, sans option (2026-11-05).
- Portée par défaut : le dépôt courant, `--all` pour tous (tous hors d'un clone) ; tenir
  sur un écran : une ligne par PR, rangée selon qui doit agir (à toi, en attente des
  autres, le reste en une ligne) ; `--all` ne montre que ce sur quoi j'ai à agir (à moi,
  mentions), `--full` tout (2026-11-05).
- Dépôts de `--all` réglables (`gh-watch set board <owner | owner/repo> on|off`) : dès
  qu'un propriétaire ou un dépôt est activé, seulement ce qui est activé (2026-11-05).
- Étape 1 : `watchlib.configure(board=…, suggest=…)` est déjà là (action proposée par
  ligne) ; l'étape 2 y ajoute les dates traitées (`handled` dans `status --json`).
- Étape 2 : une ligne notifiée sans session lancée depuis compte comme manquée, ainsi
  qu'une ligne ignorée à l'activation ; un événement plus récent que l'intervalle du
  watcher + 5 min attend son passage (« au prochain passage »). Le suivi (`watch`) est
  calculé dans `board.py` (testé sans réseau). Commande affichée pour lancer :
  `gh-watch launch <repo#n>` depuis l'étape 3 (2026-11-05).

- Étape 3 : `skip`, `unskip`, `launch` sont des commandes de premier niveau
  (`gh-watch skip`, pas `gh-watch board skip`) ; une PR n'a qu'un état, donc pas
  d'argument d'état. `gh-watch unskip` ne relance rien et ne recule pas la date retenue
  par le watcher (la ligne apparaît « écartée » dans `--auto`, `gh-watch launch` pour la
  lancer). Dans le skill, une question par ligne manquée plutôt qu'une sélection multiple :
  lancer, écarter, écarter jusqu'à la fermeture, plus tard (2026-11-05).
- Liste interactive (`gh-watch board -i`, curses) plutôt qu'un skill ou un panneau dans
  Claude : agir sur toutes les lignes, pas seulement les manquées ; `f` lance en fond
  (`--background` : analyse `--prepare` même si herdr tourne, puis notification). Seules
  les lignes dont un watcher gère l'état se lancent ; le rebase (`/git-tidy:pr-sync`)
  reste proposé à la main, en attendant [pr-sync-auto](2-git-tidy-pr-sync-auto.md)
  (2026-11-05).
- `/gh-watch:board -i` lance aussi la liste : le Bash de Claude n'a pas de terminal, donc
  pane herdr sous la session (fermé en quittant la liste) ; sans herdr, une question par
  ligne dans Claude, comme `--missed` mais sur tout ce qui est à moi (2026-11-05).

- Étape 4 : un message de review (corps, approbation comprise) qui demande un traitement
  met la PR en `feedback`, et `review-watch` lance `/review:feedback` ; une simple
  approbation, ou un message qui ne demande rien (« LGTM 👍 », liste de mots d'approbation,
  dans le doute à traiter), donne une notification seulement. Le message est traité quand
  je commente ou fais une review après, ou que le relecteur donne un avis plus récent.
  L'événement `feedback` compte les reviews des robots (comme avant), les approbations non.
  Une approbation de plus sur des retours déjà vus : notification, pas de nouvelle session.
  Brouillon : `review-watch` attend qu'il soit prêt (2026-11-06).

## À trancher

- `unrequested` sur un dépôt sans relecteurs demandés par convention (ex. dépôt perso) :
  à masquer par réglage ?
