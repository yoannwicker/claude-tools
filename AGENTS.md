# Consignes pour les agents

## Tenir la doc à jour

Toute modification du fonctionnement d'un outil (script, skill, hook, réglage, option,
mode, prérequis) met à jour la doc **dans le même commit** que le code.

- **[CLAUDE-CODE.md](CLAUDE-CODE.md)** — Claude Code (settings, profils, règles, status line,
  hooks, skills, plugins), à chaque changement de comportement : fonctionnalité, mode ou
  argument ajouté/modifié/retiré, nouveau fichier versionné (ligne **Fichiers**), prérequis,
  configuration spécifique. Un nouveau plugin reçoit sa sous-section dans *Plugins* selon le
  *Gabarit pour un nouveau plugin* ; un nouveau skill, la sienne dans *Skills*.
- **[TOOLS.md](TOOLS.md)** — même règle pour les outils hors Claude (`cl`, extension GNOME,
  herdr, mise, `home/.local/bin/{gpr,gbr}`, `home/.local/lib/`, `home/.config/shell/`) ;
  un nouvel outil reçoit sa section selon le *Gabarit pour un nouvel outil*.
- **[README.md](README.md)** — seulement si la vue d'ensemble change :
  - installation ajoutée, supprimée ou modifiée (tableau *À la carte*, scripts `setup/`,
    commandes d'`install.sh`) ;
  - grosse fonctionnalité ou outil ajouté/supprimé (intro, *Au quotidien*) ;
  - fichier ou dossier ajouté/retiré dans l'arborescence (*Structure*).
- **AGENTS.md** — nouveau fichier à ne jamais versionner (*Ne jamais ajouter* ci-dessous).

Avant de committer, relire ces fichiers et vérifier que rien n'y contredit le code.
Si aucune mise à jour n'est nécessaire, le dire explicitement dans le compte rendu.

## Ne jamais ajouter

Ne jamais versionner (ni `./install.sh adopt`) : `~/.claude/.credentials.json`, `~/.claude.json` (tokens OAuth, état, serveurs MCP
utilisateur), `~/.claude-profiles/` (dossiers de profils générés),
`~/.claude/projects/` (transcripts, mémoire), `~/.claude/plugins/`,
`~/.claude/skills/synced/`, `history.jsonl`, et dans `~/.config/herdr/` les `*.log`,
`*.sock`, `session.json`. Toujours `adopt` fichier par fichier, jamais un dossier.
