# Faire respecter (ou revoir) la règle IntelliJ MCP

- **Statut** : validée
- **Origine** : rapport du 2026-10-23 (constat 1, recommandation 2)

## Constat

La consigne du plugin `intellij` (`plugins/intellij/instructions.md`, injectée au
`SessionStart`) rend le MCP IntelliJ obligatoire pour chercher, lire et parcourir le code,
et interdit `grep`, `find` et `cat` en substitut. Sur les 30 jours, côté Claude :

| Projet | Bash | `sed`+`grep`+`cat`+`find` | Appels MCP IntelliJ |
|---|---|---|---|
| renoshield | 2 275 | 450 | 32 |
| claude_tools | 888 | 166 | 5 (+ 5 erreurs « projet inconnu ») |
| petsitter_harnessed | 345 | 59 | 35 |
| renoshield_backend_nullaway | 175 | 30 | 7 |

La consigne seule ne suffit pas. Sur claude_tools, le repli est en partie légitime : le
dépôt n'est pas ouvert dans l'IDE.

## Options

1. **Garde-fou** : hook `PreToolUse` sur Bash dans le plugin `intellij`, qui refuse
   `grep`/`rg`/`find`/`cat` (et `sed -n` en lecture) quand le projet est ouvert dans l'IDE,
   en renvoyant l'outil MCP à utiliser — sur le modèle du garde-fou Gradle de
   `build-brief`.
2. **Assouplir** : réserver l'obligation à ce que le MCP fait mieux (symboles, recherche
   structurelle, refactoring, inspections) et autoriser Bash pour lire un fichier ou
   chercher du texte.

Dans les deux cas : ouvrir claude-tools dans l'IDE, ou l'exclure explicitement de la règle.

## À trancher

- Option 1 ou 2.
- Pour l'option 1 : comment savoir, depuis un hook, que le projet est ouvert dans l'IDE
  (le MCP le sait ; un hook n'a que le `cwd`).
- Les appels `python3` (513 sur la période, surtout pour parser du JSON) sont hors sujet :
  ils ne remplacent pas un outil MCP.

## Mesure

Part des appels MCP IntelliJ par rapport à `sed`+`grep`+`cat`+`find`, par projet, au
prochain rapport.
