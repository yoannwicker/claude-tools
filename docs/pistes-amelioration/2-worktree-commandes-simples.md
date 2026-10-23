# Commandes simples en session worktree

- **Statut** : validée
- **Origine** : rapport du 2026-10-23 (constat 3, recommandation 1)

## Constat

Dans une session isolée en worktree, Claude Code refuse toute commande trop composée pour
vérifier qu'elle reste dans le worktree (*« this command is too complex to verify that it
stays inside the worktree … Split it into plain, separate commands »*). Sur les 30 jours :
46 refus sur renoshield, 7 sur renoshield_backend_nullaway, 2 sur petsitter_harnessed.
Chaque refus coûte un tour : Claude découpe la commande et recommence.

Cas typique : `cd ~/workspace/renoshield && git log … && git show …`.

## Proposition

Une consigne, lue dès le début d'une session en worktree : une commande git par appel
Bash, lancée depuis le worktree, sans `cd … &&` ni enchaînement de commandes git.

## À trancher

- Où la poser :
  - dans `git-nav`, qui crée les worktrees (`/pr`, `/br`, `gpr worktree`) : consigne dans
    les skills après `EnterWorktree`, ou hook `SessionStart` quand le `cwd` est sous
    `.claude/worktrees/` ;
  - ou dans une consigne globale, puisque `EnterWorktree` existe aussi hors de `git-nav`.
- Un hook `PreToolUse` qui reformule la commande au lieu de la laisser refuser : sans
  doute trop, la consigne suffit si elle est lue.

## Mesure

Refus d'isolation worktree au prochain rapport : viser moins de 10.
