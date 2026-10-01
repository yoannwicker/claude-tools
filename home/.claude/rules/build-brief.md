# build-brief pour les commandes Gradle

L'usage de `build-brief` est **OBLIGATOIRE** pour toute commande Gradle (`gradle ...` ou
`./gradlew ...`). Il est **INTERDIT** d'invoquer Gradle directement, même pour une commande
« rapide » ou « simple », sauf dans les cas d'exception limitativement listés ci-dessous.

- `build-brief gradle ...` pour le Gradle du PATH, `build-brief ./gradlew ...` pour le
  wrapper d'un projet donné.
- Commandes enchaînées (`&&`, `||`, `;`) : réécrire **chaque segment Gradle
  individuellement** avec `build-brief` (ne pas se contenter du premier segment).

## Exceptions (limitatives) — besoin de plus de log

Retomber sur Gradle brut est autorisé **uniquement** dans ces cas :

- `build-brief` absent du PATH dans la session en cours ;
- une stack trace est nécessaire : passer d'abord par
  `build-brief gradle --stacktrace ...` (ou `build-brief ./gradlew --stacktrace ...`) ;
  ne retomber sur Gradle brut que si cette sortie reste insuffisante ;
- la sortie intégrale non réduite est nécessaire pour un diagnostic — après avoir
  d'abord consulté le chemin du log brut renvoyé par build-brief ;
- commande non-Gradle (Maven, npm, etc.) — hors périmètre de cette règle.

## Précisions

- Sortie par défaut à garder telle quelle pour les tâches de rapport courantes
  (`tasks`, `help`, `projects`, `dependencies`, `dependencyInsight`) : elle est déjà
  courte en cas de succès et préserve le corps de ces commandes.
- Ne pas forcer explicitement `--daemon`/`--no-daemon` : laisser Gradle réutiliser le
  daemon par défaut.
- En cas d'échec transmis à un autre outil/agent : conserver le chemin du log brut
  renvoyé par build-brief.
