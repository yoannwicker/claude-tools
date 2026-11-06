# claude-tools

Configuration locale versionnée de mes outils de développement assisté par IA :
[Claude Code](https://code.claude.com/docs) (settings, status line, notifications desktop,
skills), [herdr](https://herdr.dev), l'extension GNOME `claude-notify` et les outils
`mise` globaux — appliquée dans `$HOME` par `install.sh` : symlinks pour la config, et
installation plugin par plugin pour les plugins Claude Code (chacun avec ce qu'il pose hors de
lui).
Le détail (fonctionnalités, prérequis, installation, configuration spécifique) est dans
[CLAUDE-CODE.md](CLAUDE-CODE.md) pour Claude Code et ses plugins, et dans
[TOOLS.md](TOOLS.md) pour les outils hors Claude (`cl`, extension GNOME, herdr, Herdr UI, mise).

## Installer

Tout d'un coup (liens, tous les plugins, scripts `setup/`) :

```bash
git clone git@github.com:yoannwicker/claude-tools.git ~/workspace_perso/claude-tools
cd ~/workspace_perso/claude-tools && ./install.sh
```

À la carte, Claude Code (détail : [CLAUDE-CODE.md](CLAUDE-CODE.md)) :

| Outil | Commande | Prérequis |
|---|---|---|
| Claude Code (settings, status line) | `./install.sh link` | `claude` installé et connecté, `jq`, `python3`, `gh` authentifié |
| Plugin `profiles` (commande `/profile`, `claude-profile` et fonction shell `claude` pour le terminal) | `./install.sh plugin profiles` | `jq` ; le profil de référence de `./install.sh link` |
| Plugin `git-nav` (skills `/pr`, `/br`, `/worktree`, ménage après un merge ; `gpr`, `gbr` pour le terminal) | `./install.sh plugin git-nav` | `git` ; `gh` authentifié |
| Plugin `gh-watch` (base des watchers GitHub `review-watch` et `tidy-watch`, supervision : `/gh-watch:auto-status`, `gh-watch status` ; point sur les PR : `/gh-watch:board`, `gh-watch board`) | installé avec `review` ou `git-tidy` (ou `./install.sh plugin gh-watch`) | `python3` ; systemd utilisateur |
| Plugin `git-tidy` (skills `/git-tidy:commits`, `/git-tidy:pr-sync`, `/git-tidy:ready` : commits remis au propre, rebase sur la base, PR et ticket JIRA en phase ; `/git-tidy:approved-auto` : lancer `ready` d'office quand la PR a ses approbations) | `./install.sh plugin git-tidy`, puis `tidy-watch enable` pour le mode auto | `git` ; `gh` authentifié ; MCP Atlassian pour JIRA ; `python3` et systemd utilisateur pour le mode auto |
| Plugin `pr-comments` (fils de review non résolus) | `./install.sh plugin pr-comments` | `claude` ≥ 2.1.287, `gh` authentifié |
| Plugin `intellij` (MCP IntelliJ + consigne) | `./install.sh plugin intellij` | IntelliJ avec le serveur MCP sur le port 64342 |
| Plugin `notify` (notifications desktop) | `./install.sh plugin notify` | `python3-gi`, `gdbus`, `xprop`, `jq`, gnome-terminal |
| Plugin `herdr-session` (reprise des sessions par herdr) | `./install.sh plugin herdr-session` | herdr et son intégration Claude (`./setup/20-herdr.sh`) |
| Plugin `build-brief` (consigne et garde-fou Gradle) | `./install.sh plugin build-brief` | `build-brief` dans le PATH, `python3` |
| Plugin `session-analysis` (analyse des sessions avec AgentsView, qu'il installe) | `./install.sh plugin session-analysis` | `python3`, `curl` |
| Plugin `review` (agent reviewer, skills `/review:diff`, `/review:pr`, `/review:feedback` : relire son diff ou la PR d'un collègue, traiter les retours reçus ; `/review:pr-auto`, `/review:feedback-auto` : les lancer d'office depuis les notifications GitHub) | `./install.sh plugin review`, puis `review-watch enable` pour le mode auto | `git`, `python3` ; `gh` authentifié ; `git-nav` pour chercher une PR par mots-clés ; systemd utilisateur pour le mode auto |

Plusieurs plugins d'un coup : `./install.sh plugin <nom>…`, tous : `./install.sh plugin --all`
(c'est ce que fait `./install.sh`). Relancer met à jour. `./install.sh plugin --remove <nom>…`
désinstalle, liens compris. Activer un plugin installé dans un profil reste à `/profile show`.

À la carte, outils externes (détail : [TOOLS.md](TOOLS.md)) :

| Outil | Commande | Prérequis |
|---|---|---|
| mise (outils globaux) | `./setup/10-mise.sh` | `curl` |
| herdr (+ intégrations Claude/Copilot ; au choix, client graphique Herdr UI) | `./setup/20-herdr.sh [--ui]` | `curl` ; Linux ou macOS. Herdr UI : glibc ≥ 2.39 et `sudo` (APT, DNF ou pacman), ou Homebrew |
| Lanceur `cl` (choix des espaces de travail) | `./install.sh link && ./setup/50-cl.sh` | `claude` |
| Extension GNOME `claude-notify` (pastille des notifications du plugin `notify`) | `./install.sh link && ./install.sh plugin notify && ./setup/30-gnome.sh` | GNOME Shell 46 |

Sans GNOME : désactiver le plugin `notify` dans chaque profil (`"notify@claude-tools": false`
dans `enabledPlugins` de `profiles/*.json`, ou `/profile show`). Le premier `enable` d'une extension GNOME fraîchement liée peut
demander une déconnexion/reconnexion de session.

## Au quotidien

- `git status` dans ce repo montre ce qui a changé dans ma config (les fichiers de
  `$HOME` sont des liens vers `home/`) : relire, committer.
- `cl <projet> [args claude…]` (lié dans `~/.local/bin`) : ouvre Claude Code sur un
  projet des espaces de travail choisis à l'installation (nom exact, sinon partiel
  insensible à la casse, sinon menu). `cl --list | --add [chemin] | --remove <n>` pour les
  faire évoluer, `cl --setup` pour refaire la sélection.
- Profils : `~/.claude/settings.json` est le profil de référence
  (`home/.claude/settings.json`) ; un profil (`profiles/<profil>.json`) n'en surcharge que les plugins
  actifs et les MCP coupés. `claude-profile switch <profil>` (ou `cl -P <profil> <projet>`) lance Claude sur
  `~/.claude-profiles/<profil>/`, généré depuis `~/.claude` ; `claude` seul part sur le
  profil du projet s'il y en a un (`claude-profile project <profil>`, `/profile project` :
  `.claude/profile.local`, non versionné), sinon sur le profil par défaut s'il y en a un
  (`claude-profile default <profil>`, `/profile default`), sinon sur le profil de référence. Dans une
  session, `/profile` propose la liste des profils et `/profile <profil>` relance la
  conversation dans ce profil ; `/profile show [<profil>]` montre ce qui y est actif et
  (dés)active ses plugins et MCP, `/profile create <nom>` crée un profil.
- Fils de review non résolus de mes PR (et de celles que je relis) : ligne `💬` au-dessus
  du prompt, `c` ou `/pr-review` pour les parcourir, les envoyer à Claude, répondre,
  résoudre (plugin `pr-comments`).
- `/pr [numéro | mots-clés]`, `/br [nom | mots-clés]` : trouver une PR ou une branche,
  la charger en contexte et se placer dessus (branche courante ou worktree) ;
  `/worktree clear` supprime les worktrees qu'aucune session n'utilise ;
  après un merge (`gh pr merge`, `git merge`, `git push origin <branche>:main`, ou « c'est mergé »), Claude propose de
  supprimer la branche mergée, son worktree et sa branche distante (plugin `git-nav` ;
  `gpr`, `gbr` dans le terminal, `gbr cleanup` pour ce ménage).
- `/git-tidy:commits [n] [--base <base>]` : redécouper et reformuler les commits d'une branche avant
  relecture ou avant merge (sauvegarde, push forcé seulement sur accord) ; `/git-tidy:pr-sync` : rebaser
  la PR si elle est en retard (sur sa base, une autre branche, ou toute la pile de PR), remettre sa description en phase et la raccorder au
  ticket JIRA ou à l'issue ; `/git-tidy:ready` : les deux d'affilée avant merge, puis la
  demande de relecture si elle manque (relecteurs du dépôt classés par l'historique), ou,
  PR approuvée, le ticket JIRA passé « En validation » et le message Slack pour le testeur ;
  `/git-tidy:approved-auto` : lancer `ready` d'office quand ma PR a ses approbations (2 par
  défaut, dépôt par dépôt, via `tidy-watch`) (plugin `git-tidy`).
- `/review:diff` : faire relire mon diff avant commit ou PR par l'agent `reviewer` (code
  ajouté seulement) ; `/review:pr <n…>` : relire la PR d'un collègue, ou plusieurs PR
  liées (pile, même sujet) avec leur cohérence, et y poster les commentaires retenus ; `/review:feedback` : traiter les retours reçus sur ma PR
  (solution, options ou à discuter pour chacun, puis fixups et réponses). Chaque point est
  priorisé et validé avant d'être envoyé ou traité (plugin `review`).
- `/review:pr-auto` : lancer ces revues d'office à la demande de review ;
  `/review:feedback-auto` : lancer le plan de traitement au retour de revue reçu sur mes PR.
  Dépôt par dépôt (`on`/`off`, ou choix dans la liste) ; sinon une notification, dont le
  clic lance la session. La session (herdr, ou analyse en fond reprise au clic) attend ma
  validation avant de poster ou de répondre (`review-watch`, plugin `review`).
- `/gh-watch:auto-status` (ou `gh-watch status` dans le terminal) : ce qui tourne — timers des
  watchers (`review-watch`, `tidy-watch`), dernier et prochain passage, dépôts suivis,
  sessions lancées (et quand) ou prêtes à reprendre ; `--history` : derniers déclenchements
  (`gh-watch history --since 24h` : session lancée, notification, ignoré, en attente) ;
  `--dry-run` : ce qu'un passage ferait (plugin `gh-watch`, installé avec `review` et `git-tidy`).
- `/gh-watch:board [<owner/repo> | --all]` (ou `gh-watch board`) : le point sur mes PR
  ouvertes et les relectures qu'on attend de moi, sur le dépôt courant ou tous (`--all` :
  seulement ce sur quoi j'ai à agir, dans les dépôts activés par `gh-watch set board`) —
  depuis quand, action proposée ; `--missed` : les actions que les watchers ont manquées,
  à lancer ou écarter (`gh-watch launch`, `gh-watch skip`) ; `gh-watch board -i` : la même
  liste, interactive, pour lancer (en fond au choix) ou écarter ligne par ligne
  (`/gh-watch:board -i` : dans un pane herdr, sinon par questions) (plugin `gh-watch`).
- `/session-analysis:report [projet…]` : rapport sur les 30 derniers jours d'usage des
  agents (AgentsView), rangé dans `docs/analyses-sessions/` pour ce dépôt ;
  `/session-analysis:session` : bilan de la session en cours (plugin `session-analysis`).
- `dot` (lié dans `~/.local/bin`) : dérive git, état des liens et des plugins, `mise upgrade`,
  `herdr update`, `claude update`.
- `./install.sh adopt <fichier>` : versionner un nouveau fichier de `$HOME` (déplacé dans
  `home/`, remplacé par un lien). `./install.sh status` : état de chaque fichier géré et de
  chaque plugin (installé ou non, à jour ou non, liens posés), liens morts vers le dépôt.
- Après un `git pull` qui touche `plugins/` : `./install.sh plugin <nom>` (ou `--all`) ;
  `./install.sh plugin --remove <nom>` pour retirer un plugin et ce qu'il a posé.
- `./install.sh capture <fichier>` : repli pour un fichier qu'un outil réécrit en
  remplaçant le lien (recopie `$HOME` → `home/`).

## Structure

```
install.sh          link | plugin | setup | status | adopt | capture (défaut : link + plugin --all + setup)
home/               miroir de $HOME, un lien par fichier
  .bash_aliases     charge .config/shell/*.sh (posés par les plugins profiles et git-nav, voir TOOLS.md)
  .claude/          settings.json (le profil de référence, voir CLAUDE-CODE.md), statusline-*.sh
  .config/          herdr/config.toml, mise/config.toml
  .local/           bin/{cl,dot}, share/gnome-shell/extensions/claude-notify@ywicker/
.claude-plugin/     marketplace.json : ce dépôt comme marketplace locale « claude-tools »
plugins/            plugins Claude Code, chacun avec son setup.sh s'il pose quelque chose hors de lui
                    (liens, contrôles ; lu par install.sh plugin) : pr-comments/ (repris
                    d'aguiddir/claude-config), intellij/, profiles/ (bin/claude-profile, shell/claude-profile.sh),
                    git-nav/ (skills /pr, /br, /worktree, branch-cleanup, hook merge-watch, bin/{gpr,gbr}, lib/ et shell/git-tools.sh),
                    gh-watch/ (lib/watchlib.py commun aux watchers, bin/gh-watch et skill
                    /gh-watch:auto-status pour les superviser, lib/board.py, lib/tui.py et skill
                    /gh-watch:board pour le point sur les PR),
                    git-tidy/ (skills /git-tidy:commits, :pr-sync, :ready et :approved-auto,
                    bin/tidy-watch, timer systemd tidy-watch),
                    notify/ (hooks et scripts des notifications desktop), herdr-session/ (hook herdr),
                    build-brief/ (consigne et garde-fou Gradle), session-analysis/ (skills
                    /session-analysis:report et :session, bin/{agentsview-up,session-analysis-collect}),
                    review/ (agent reviewer, skills /review:diff, :pr, :feedback, :pr-auto et :feedback-auto,
                    bin/{review-post,review-watch}, timer systemd review-watch, profil Herdr UI)
profiles/           profils (<nom>.json : surcharge des plugins actifs du profil de référence — vidal, lean —, voir `claude-profile`)
setup/              scripts idempotents des outils hors plugins : 10-mise, 20-herdr, 30-gnome, 50-cl
docs/               suivi de l'usage des agents : analyses-sessions/ (rapports datés et leurs indicateurs .json),
                    pistes-amelioration/ (pistes préfixées par leur priorité 1, 2, 3)
CLAUDE-CODE.md      Claude Code : settings, profils, plugins
TOOLS.md            outils hors Claude : cl, extension GNOME, herdr, Herdr UI, mise
AGENTS.md           consignes pour les agents (CLAUDE.md l'importe)
```
