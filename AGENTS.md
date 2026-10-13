# Consignes pour les agents

## Tenir la doc à jour

Toute modification du fonctionnement d'un outil (script, skill, hook, réglage, option,
mode, prérequis) met à jour la doc **dans le même commit** que le code.

- **[TOOLS.md](TOOLS.md)** — à chaque changement de comportement : fonctionnalité,
  mode ou argument ajouté/modifié/retiré, nouveau fichier versionné (ligne **Fichiers**),
  prérequis, configuration spécifique. Respecter le gabarit de l'outil concerné ;
  un nouvel outil reçoit sa section selon le *Gabarit pour un nouvel outil*.
- **[SHELL.md](SHELL.md)** — même règle que `TOOLS.md` pour les outils shell hors Claude
  (ex. `home/.local/bin/{gpr,gbr}`, `home/.local/lib/`, `home/.config/shell/`), même gabarit.
- **[README.md](README.md)** — seulement si la vue d'ensemble change :
  - installation ajoutée, supprimée ou modifiée (tableau *À la carte*, scripts `setup/`,
    commandes d'`install.sh`) ;
  - grosse fonctionnalité ou outil ajouté/supprimé (intro, *Au quotidien*) ;
  - fichier ou dossier ajouté/retiré dans l'arborescence (*Structure*) ;
  - nouveau fichier à ne jamais versionner (*Ne jamais ajouter*).

Avant de committer, relire ces fichiers et vérifier que rien n'y contredit le code.
Si aucune mise à jour n'est nécessaire, le dire explicitement dans le compte rendu.
