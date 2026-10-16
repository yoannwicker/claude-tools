# build-brief pour les commandes Gradle

L'usage de `build-brief` est **OBLIGATOIRE** pour toute commande Gradle (`gradle ...` ou
`./gradlew ...`). Il est **INTERDIT** d'invoquer Gradle directement, même pour une commande
« rapide » ou « simple », sauf dans les cas d'exception limitativement listés ci-dessous.

- `build-brief gradle ...` pour le Gradle du PATH, `build-brief ./gradlew ...` pour le
  wrapper d'un projet donné.
- Commandes enchaînées (`&&`, `||`, `;`, `|`) : réécrire **chaque segment Gradle
  individuellement** avec `build-brief` (ne pas se contenter du premier segment).

## Besoin de plus de log : rester dans build-brief

Dans cet ordre, sans quitter build-brief :

1. stack trace : `build-brief ./gradlew --stacktrace ...` ;
2. log brut complet : consulter le chemin du log renvoyé par build-brief ;
3. sortie intégrale non réduite en direct (y compris avec `--info`/`--debug`) :
   `build-brief --mode raw ./gradlew ...`.

Rapports de tests : lire `build/test-results/` et `build/reports/tests/`.

## Exceptions (limitatives) — Gradle brut

Retomber sur Gradle brut est autorisé **uniquement** dans ces cas :

- `build-brief` absent du PATH dans la session en cours ;
- gestion du daemon ou simple info : `./gradlew --stop`, `--status`, `--version` ;
- dernier recours, quand les trois niveaux ci-dessus restent insuffisants (build
  `--continuous`, doute sur la sortie de build-brief lui-même) : préfixer la commande par
  `BUILD_BRIEF_BYPASS=1` (ex. `BUILD_BRIEF_BYPASS=1 ./gradlew test`) ;
- commande non-Gradle (Maven, npm, etc.) — hors périmètre de cette règle.

Un hook `PreToolUse` refuse tout autre appel Bash à `gradle`/`gradlew` sans `build-brief` :
relancer alors la commande proposée dans le message de refus.

## Précisions

- Sortie par défaut à garder telle quelle pour les tâches de rapport courantes
  (`tasks`, `help`, `projects`, `dependencies`, `dependencyInsight`) : elle est déjà
  courte en cas de succès et préserve le corps de ces commandes.
- Ne pas forcer explicitement `--daemon`/`--no-daemon` : laisser Gradle réutiliser le
  daemon par défaut.
- En cas d'échec transmis à un autre outil/agent : conserver le chemin du log brut
  renvoyé par build-brief.
