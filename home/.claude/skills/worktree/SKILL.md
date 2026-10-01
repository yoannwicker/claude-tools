---
name: worktree
description: Lister les worktrees git du dépôt courant, ou supprimer ceux qu'aucune session n'utilise (clear)
argument-hint: "[list | clear]"
allowed-tools: Bash(~/.claude/skills/worktree/scan.sh:*), Bash(git worktree list:*), Bash(git worktree remove:*), Bash(git worktree prune:*), AskUserQuestion
---

Argument : `$ARGUMENTS` (vide = `list`)

## Scanner

Lancer `~/.claude/skills/worktree/scan.sh` depuis le dépôt courant. Il renvoie une ligne
TSV par worktree, `<verdict> <chemin> <branche> <détail>` :

| Verdict | Sens | Supprimable |
|---|---|---|
| `main` | dépôt principal | jamais |
| `current` | worktree de cette session | jamais |
| `locked` | verrouillé (`git worktree lock`) | jamais |
| `busy` | un processus a son cwd dedans (session Claude, shell, IDE) ; détail = `pid:commande` | jamais |
| `dirty` | modifications non commitées ou fichiers non suivis | jamais (pas de `--force`) |
| `free` | aucune session, arbre propre ; détail = commits non poussés | oui |

## `list`

Afficher un tableau (verdict, chemin raccourci en `~`, branche, détail) et s'arrêter.

## `clear`

1. Afficher le même tableau. S'il n'y a aucun `free` : le dire, lancer
   `git worktree prune`, s'arrêter.
2. Confirmer avec `AskUserQuestion` (header « Nettoyage ») avant toute suppression :
   - **Tout supprimer** — les N worktrees `free` (les lister dans la description).
   - **Choisir** — j'indique ensuite par écrit lesquels garder ou supprimer.
   - **Annuler**.
   Signaler dans la description les worktrees `free` qui ont des commits non poussés ou
   pas d'upstream : la branche locale est conservée, mais c'est le seul endroit où ces
   commits existent.
3. Pour chaque worktree retenu : `git worktree remove <chemin>` (sans `--force` ; en cas
   d'échec, rapporter le message et passer au suivant). Ne jamais supprimer les branches.
4. `git worktree prune`, puis afficher `git worktree list` et un récapitulatif
   (supprimés, ignorés et pourquoi).
