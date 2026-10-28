---
name: branch-cleanup
description: Supprimer une branche git une fois mergée — worktree, branche locale, sauvegardes backup/ et branche distante — après vérification du merge et confirmation. À utiliser dès qu'une branche ou une PR vient d'être mergée (gh pr merge, git merge, git push <branche>:main, « c'est mergé », « PR acceptée », PR trouvée à l'état MERGED), ou pour faire le ménage des branches déjà mergées.
user-invocable: false
allowed-tools: Bash(gbr:*), Bash(gh pr list:*), Bash(git for-each-ref:*), ExitWorktree
---

Pas de commande `/` : Claude lance ce skill de lui-même après un merge — le hook du plugin
le lui rappelle après `gh pr merge`, `git merge <branche>` ou
`git push <remote> <branche>:<branche par défaut>`, avec le plan déjà calculé —,
quand l'utilisateur dit qu'une branche ou une PR est mergée, ou quand `/pr`, `/br`,
`/worktree release` tombent sur une PR mergée.

Tout passe par `gbr cleanup` (`gbr --help`), qui vérifie que rien ne sera perdu avant de
supprimer : PR mergée (sans PR : branche contenue dans la base) et aucun commit local hors
de la PR, worktree ni modifié ni utilisé par un autre processus. Rien n'est supprimé sans
confirmation ; ne jamais refaire ces vérifications ou suppressions à la main.

## 1. Le plan

- Plan fourni par le hook (`gbr cleanup --dry-run …` dans le contexte) → le reprendre.
- Sinon `gbr cleanup --dry-run <branche>` (ou `--pr <n>`) : la branche mergée d'après le
  contexte, sinon la branche courante.
- Depuis la branche par défaut sans branche désignée : candidates = branches locales
  (`git for-each-ref --format='%(refname:short)' refs/heads`) dont la PR est mergée
  (`gh pr list --state merged --author @me -L 50 --json headRefName,number,mergedAt`).
  Aucune → le dire et s'arrêter. Plusieurs → `AskUserQuestion` (header « Branches »,
  `multiSelect`, 4 au plus, les plus récemment mergées), puis un plan par branche.

## 2. Bloqué ?

`bloqué : …` (code 1) → le dire tel quel et s'arrêter, sauf un cas :
`on est dans le worktree de <branche>` → en sortir comme `/worktree release` : `ExitWorktree`
avec `action: "keep"` (charger son schéma via ToolSearch `select:ExitWorktree` si besoin ;
jamais `remove`), ou `cd <dépôt principal>` si la session a été lancée dedans ; puis
relancer le dry-run.

Commits absents de la PR : proposer une nouvelle branche pour les garder. Jamais de stash,
jamais de `--force`.

## 3. Confirmer, puis supprimer

Montrer le plan, puis `AskUserQuestion` (header « Ménage ») : **Tout supprimer** /
**Local seulement** (garder la branche distante) / **Annuler**.

`gbr cleanup --yes <branche>` (`--local` pour *Local seulement*) : supprime le worktree,
passe sur la base à jour si c'était la branche courante, supprime la branche locale, les
sauvegardes et la branche distante.

Finir par une ligne : ce qui a été supprimé, ce qui a été gardé et pourquoi, et où l'on est
(branche + dossier).
