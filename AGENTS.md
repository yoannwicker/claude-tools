# Consignes pour les agents

## Tenir la doc à jour

Toute modification du fonctionnement d'un outil (script, skill, hook, réglage, option,
mode, prérequis) met à jour la doc **dans le même commit** que le code.

- **[CLAUDE-CODE.md](CLAUDE-CODE.md)** — Claude Code (settings, profils, status line,
  hooks, skills, plugins), à chaque changement de comportement : fonctionnalité, mode ou
  argument ajouté/modifié/retiré, nouveau fichier versionné (ligne **Fichiers**), prérequis,
  configuration spécifique. Un nouveau plugin reçoit sa sous-section dans *Plugins* selon le
  *Gabarit pour un nouveau plugin* (voir *Documenter un plugin* ci-dessous) ; un nouveau
  skill, la sienne dans *Skills*.
- **[TOOLS.md](TOOLS.md)** — même règle pour les outils hors Claude (`cl`, extension GNOME,
  herdr, mise, chargement du shell) ;
  un nouvel outil reçoit sa section selon le *Gabarit pour un nouvel outil*.
- **[README.md](README.md)** — seulement si la vue d'ensemble change :
  - installation ajoutée, supprimée ou modifiée (tableau *À la carte*, scripts `setup/`,
    commandes d'`install.sh`) ;
  - grosse fonctionnalité ou outil ajouté/supprimé (intro, *Au quotidien*) ;
  - fichier ou dossier ajouté/retiré dans l'arborescence (*Structure*).
- **AGENTS.md** — nouveau fichier à ne jamais versionner (*Ne jamais ajouter* ci-dessous).

Avant de committer, relire ces fichiers et vérifier que rien n'y contredit le code.
Si aucune mise à jour n'est nécessaire, le dire explicitement dans le compte rendu.

### Documenter un plugin

Un plugin peut être installé seul, sans le reste de la config : sa sous-section dans
*Plugins* de CLAUDE-CODE.md se suffit à elle-même.

- Tout ce qui le concerne y est : rôle, fichiers (y compris ce qu'il pose hors de
  `plugins/<plugin>/`, comme les liens de son `setup.sh`), profils où il est activé, prérequis, tests,
  fonctionnement complet (commandes, touches, configuration). Découper en `####` si la
  section est longue.
- Ailleurs dans la doc, ne pas redécrire le plugin : une phrase et un lien vers sa
  sous-section suffisent, et seulement là où c'est vraiment lié.
- S'il s'utilise seul, ajouter *Installation hors de ce dépôt* : les commandes pour
  quelqu'un qui ne clone le dépôt que pour ce plugin (marketplace, `claude plugin install`,
  liens, premiers réglages), et ce qui l'empêche de s'installer autrement (ex. depuis
  GitHub) s'il dépend du dépôt.
- Le lister aussi dans la ligne **Fichiers** en tête de CLAUDE-CODE.md, et le déclarer dans
  `.claude-plugin/marketplace.json` : c'est la liste que lit `./install.sh plugin`.

### Ce qu'un plugin fournit pour s'installer seul

`./install.sh plugin <plugin>` doit suffire à l'installer, le mettre à jour et le retirer
(détail : CLAUDE-CODE.md, *Installation des plugins*).

- Tout ce dont il a besoin hors de lui (lien vers un script de `bin/` pour le terminal,
  fonction shell pour `~/.config/shell/`, contrôle d'un outil externe, ménage d'un réglage)
  est déclaré dans `plugins/<plugin>/setup.sh` : `links=( "<chemin dans le plugin>
  <destination>" … )`, et seulement si un lien ne suffit pas, `on_install`, `on_remove`,
  `on_status` (idempotents, `note` pour un simple avertissement).
- Jamais dans `home/` (relié par `./install.sh link`, pour tous) ni dans `setup/` (outils
  hors plugins) : un fichier du plugin vit dans `plugins/<plugin>/`, même s'il est utilisé
  hors de Claude.
- Pas de ménage écrit à la main pour les anciens liens d'avant le plugin : devenus morts,
  ils sont retirés par `./install.sh`.
- Vérifier sur un HOME de test (`HOME=$(mktemp -d)`, depuis une copie du dépôt pour ne pas
  toucher au `settings.json` versionné) : `./install.sh plugin <plugin>`, `status`,
  `plugin --remove <plugin>`, `status`.

## Analyses de sessions et pistes d'amélioration

Rapports d'analyse et pistes retenues : voir [docs/README.md](docs/README.md) (nommage,
priorités, statuts).

## Ne jamais ajouter

Ne jamais versionner (ni `./install.sh adopt`) : `~/.claude/.credentials.json`, `~/.claude.json` (tokens OAuth, état, serveurs MCP
utilisateur), `~/.claude-profiles/` (dossiers de profils générés),
`~/.claude/projects/` (transcripts, mémoire), `~/.claude/plugins/`,
`~/.claude/skills/synced/`, `history.jsonl`, et dans `~/.config/herdr/` les `*.log`,
`*.sock`, `session.json`. Toujours `adopt` fichier par fichier, jamais un dossier.
