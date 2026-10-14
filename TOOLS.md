# Outils

Outils du terminal et du poste, hors Claude Code, même s'ils peuvent lui servir de socle
(la configuration de Claude et ses plugins : [CLAUDE-CODE.md](CLAUDE-CODE.md)). Une section
par outil, même gabarit (voir [Gabarit pour un nouvel outil](#gabarit-pour-un-nouvel-outil)).

## Chargement du shell

`home/.bash_aliases` ne contient rien d'autre que le chargement de
`~/.config/shell/*.sh`, un fichier par famille d'outils. Le `.bashrc` Ubuntu par défaut
source `~/.bash_aliases` (sinon y ajouter `. ~/.bash_aliases`). Fonctions et alias n'y
sont chargés que dans un shell interactif : ils n'existent pas dans les commandes `!` ni
dans le shell de Claude, qui n'utilisent que les scripts de `~/.local/bin`.
Seule exception côté Claude : `claude-profile.sh`, qui fait passer `claude` par
`claude-profile run` (voir [CLAUDE-CODE.md](CLAUDE-CODE.md#bascule-depuis-une-session)).

## Lanceur `cl`

**Rôle** : lanceur de Claude Code sur un projet des espaces de travail choisis.

**Fichiers** : `home/.local/bin/cl` (espaces de travail dans `~/.config/cl/workspaces`,
non versionné).

**Prérequis** : `claude` ; `claude-profile` (voir [CLAUDE-CODE.md](CLAUDE-CODE.md#claude-profile)).

**Installation** : `./install.sh link && ./setup/50-cl.sh`.

`cl [projet] [arguments claude…]` : équivalent de `cop` pour Claude. Cherche `projet`
dans les espaces de travail configurés : nom exact, sinon correspondance partielle
insensible à la casse, sinon menu de tous les projets (menu aussi dès que plusieurs
correspondent ; un nom présent dans deux espaces s'affiche `nom (espace)`). Puis `cd` et
`exec claude` avec les arguments restants (`cl babel -c`, `cl vira --resume`). Script et
non fonction shell : le terminal revient dans son dossier d'origine à la sortie.

Espaces de travail : propres à chaque machine, donc dans `~/.config/cl/workspaces` (un
chemin par ligne, non versionné). `setup/50-cl.sh` les fait choisir à l'installation :
il propose les dossiers de `$HOME` qui contiennent des dépôts git (numéros pour cocher,
chemin pour en ajouter un) ; sans terminal (relancé par `./install.sh setup`) il garde la
config existante, sinon retient les `~/workspace*`. Ensuite, en chemin :

- `cl --list` : espaces configurés avec leur nombre de projets (`absent` si disparu) ;
- `cl --add [chemin…]` : ajoute (dossier courant par défaut) ;
- `cl --remove <chemin|numéro>…` : retire (numéros de `--list`) ;
- `cl --setup` : refait la sélection interactive.

`CL_WORKSPACE=dir1:dir2` remplace la config le temps d'une commande ; sans config, repli
sur `~/workspace`.

`cl` lance Claude par `claude-profile run`, et `cl -P <profil> [projet] …` par
`claude-profile switch <profil>` : `/profile` peut ensuite relancer la session dans un autre
profil (voir [`profiles`](CLAUDE-CODE.md#profiles)).

## Extension GNOME `claude-notify@ywicker`

**Rôle** : pastille dans le panneau GNOME avec le nombre de notifications Claude Code en
attente ; menu pour revenir sur une session ou tout effacer.

**Fichiers** : `home/.local/share/gnome-shell/extensions/claude-notify@ywicker/`
(`extension.js`, `metadata.json`, `stylesheet.css`).

**Prérequis** : GNOME Shell 46 (`shell-version` dans `metadata.json`), les scripts de
notification de Claude ([CLAUDE-CODE.md](CLAUDE-CODE.md#notifications-desktop)) (l'extension appelle `~/.claude/notify-click.sh`).

**Installation** : `./install.sh link` puis `./setup/30-gnome.sh`
(`gnome-extensions enable claude-notify@ywicker`). Après un premier lien, GNOME Shell ne
voit l'extension qu'au prochain login : se déconnecter/reconnecter puis relancer le script.

## herdr

**Rôle** : gestionnaire de workspaces terminal pour agents IA (panes, onglets, état des
agents, worktrees).

**Fichiers** : `home/.config/herdr/config.toml`, seul fichier de configuration. Restent
locaux dans `~/.config/herdr/` : `*.log`, `*.sock`, `session.json`, `release-notes.json`,
`.plugins.lock`. Le binaire (`~/.local/bin/herdr`) n'est pas versionné.

**Prérequis** : Linux ou macOS, `curl`.

**Installation** : `./setup/20-herdr.sh`, soit
`curl -fsSL https://herdr.dev/install.sh | sh`, puis `herdr integration install claude`
(et `copilot` si la CLI Copilot est présente). Mise à jour : `herdr update` (fait par `dot`).

**Configuration spécifique** :
- `onboarding = false` ; `[update] channel = "stable"`. Toute section ajoutée ensuite
  (`[keys]`, `[theme]`, `[ui]`, `[terminal]`) se documente ici.
- Intégration Claude : herdr génère `~/.claude/hooks/herdr-agent-state.sh` (fichier
  « managed by herdr », non versionné) et ajoute un hook `SessionStart` dans
  `settings.json` avec un **chemin absolu**. Les profils (`profiles/*.json`, voir [CLAUDE-CODE.md](CLAUDE-CODE.md#profils)) portent la variante
  portable `[ -f "$HOME/.claude/hooks/herdr-agent-state.sh" ] && bash … session || true` ;
  comme herdr ne la reconnaît pas, chaque `integration install` ajoute un doublon absolu,
  que `setup/20-herdr.sh` retire (en écrivant à travers le lien). `dot` rejoue ce script
  après `herdr update`.
- Vérifier : `herdr integration status` → `claude: current`.

## mise

**Rôle** : installation d'outils en espace utilisateur (pas de sudo sur la machine pro).

**Fichiers** : `home/.config/mise/config.toml` — outils globaux : `jq`.

**Installation** : `./setup/10-mise.sh` (`curl https://mise.run | sh` si absent, puis
`mise install`). L'activation shell (`eval "$(mise activate bash)"`) reste dans le
`.bashrc`, hors repo pour l'instant. Les versions `node`/`java` des projets sont dans le
`mise.toml` de chaque repo, pas ici.

## Gabarit pour un nouvel outil

```
## <outil>
**Rôle** : …
**Fichiers** : home/… (ce qui reste local : …)
**Prérequis** : …
**Installation** : ./setup/NN-<outil>.sh — commandes
**Configuration spécifique** : …
```
