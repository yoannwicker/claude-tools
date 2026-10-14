# Code Search and Refactoring

Les outils JetBrains MCP (serveur `intellij` du plugin `intellij`, outils
`mcp__plugin_intellij_intellij__*`, à charger via ToolSearch s'ils sont différés) sont
**OBLIGATOIRES** pour toute opération listée ci-dessous. Il est **INTERDIT** d'utiliser
`grep`/`rg`/`find`/`cat` (Bash) comme substitut, même pour une recherche "rapide" ou
"simple", sauf dans les deux cas d'exception suivants :

- le serveur MCP `intellij` n'est pas disponible/joignable dans la session en cours ;
- le repo/projet concerné n'est pas accessible via ce MCP (projet non ouvert dans l'IDE,
  hors du scope des projets listés par le serveur, etc.).

Dans ces cas d'exception **UNIQUEMENT**, retomber sur Bash (`grep`/`find`) est autorisé. En
dehors de ces cas, si un outil JetBrains MCP existe pour l'opération demandée, il doit être
utilisé — **PAS DE CONTOURNEMENT**.

## Search

- **Rechercher un symbole** (classe, méthode, champ) → `mcp__plugin_intellij_intellij__search_symbol`
- **Rechercher par pattern structurel** (tous les appels à une méthode, toutes les
  implémentations d'une interface) → `mcp__plugin_intellij_intellij__search_structural`
- **Rechercher du texte dans les fichiers** → `mcp__plugin_intellij_intellij__search_text` /
  `mcp__plugin_intellij_intellij__search_regex` (au lieu de `grep`/`rg`, systématiquement)
- **Obtenir la signature ou la doc d'un symbole** → `mcp__plugin_intellij_intellij__get_symbol_info`
- **Lister/parcourir des fichiers** → `mcp__plugin_intellij_intellij__list_directory_tree` /
  `mcp__plugin_intellij_intellij__search_file` (au lieu de `find`/`ls`)

## Refactoring

- **Renommer un symbole** dans tout le projet → `mcp__plugin_intellij_intellij__rename_refactoring` (JAMAIS via
  search+replace manuel)
- **Corriger un problème via quick-fix** → `mcp__plugin_intellij_intellij__apply_quick_fix`
- **Valider le code après modification** → `mcp__plugin_intellij_intellij__get_inspections` /
  `mcp__plugin_intellij_intellij__get_file_problems`
- **Compiler et vérifier après édition** → `mcp__plugin_intellij_intellij__build_project`

## Diff

- **Afficher le diff des modifications non commitées** (working tree vs HEAD) → d'abord
  `mcp__plugin_intellij_intellij__git_status` pour lister les fichiers modifiés, puis
  `mcp__plugin_intellij_intellij__invoke_ide_action` avec `actionId: "Diff.ShowDiff"` (ou
  `"Vcs.Diff.ShowDiffInEditorTab"`) et `filePaths` pointant sur le(s) fichier(s) concerné(s),
  pour ouvrir le diff directement dans l'IDE plutôt que via `git diff` en terminal.
- **Comparer avec l'arbre de travail depuis un ref/commit** →
  `mcp__plugin_intellij_intellij__invoke_ide_action` avec `actionId: "Git.Ref.Diff.With.Local"`.
- **Découvrir une autre action de diff disponible** (comparaison HEAD/staged/local, diff
  dans une fenêtre séparée, etc.) → `mcp__plugin_intellij_intellij__search_ide_actions` avec une requête comme
  `"diff"` ou `"compare"` avant d'appeler `mcp__plugin_intellij_intellij__invoke_ide_action`.
