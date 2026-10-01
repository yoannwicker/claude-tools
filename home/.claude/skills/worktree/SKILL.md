---
name: worktree
description: Lister les worktrees git du dépôt courant, supprimer ceux qu'aucune session n'utilise (clear), ou libérer celui de la session (release)
argument-hint: "[list | clear | release]"
allowed-tools: Bash(~/.claude/skills/worktree/scan.sh:*), Bash(git worktree list:*), Bash(git worktree remove:*), Bash(git worktree prune:*), Bash(git -C:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(cd:*), AskUserQuestion, ExitWorktree
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

## `release`

Supprimer le worktree sur lequel est la session, puis revenir sur le dépôt principal.

1. Lancer le scan. Le worktree de la session est la ligne `current` ; s'il n'y en a pas
   (la session est sur `main`), le dire et s'arrêter.
2. Vérifier son état (`git status --porcelain`, `git rev-parse --abbrev-ref @{u}`,
   `git rev-list --count @{u}..HEAD`) :
   - verrouillé ou modifications non commitées / fichiers non suivis → refuser, lister
     ce qui bloque, s'arrêter (jamais de `--force`, jamais de stash) ;
   - commits non poussés ou pas d'upstream → confirmer avec `AskUserQuestion` (header
     « Release ») : **Supprimer** (la branche locale est conservée) / **Annuler** ;
   - sinon, enchaîner sans redemander.
3. **Quitter le worktree** : appeler `ExitWorktree` avec `action: "keep"` (charger son
   schéma via ToolSearch `select:ExitWorktree` si besoin ; jamais `remove`, qui supprime
   aussi la branche). Si l'outil répond qu'aucune session worktree n'est active (session
   lancée directement dans le worktree), faire `cd <dépôt principal>`.
4. Depuis le dépôt principal : `git -C <dépôt principal> worktree remove <chemin>` (sans
   `--force` ; en cas d'échec, rapporter le message et s'arrêter), puis
   `git -C <dépôt principal> worktree prune`. Ne jamais supprimer la branche.
5. Afficher `git worktree list` et une ligne indiquant où est la session (branche +
   dossier) et la branche conservée.
