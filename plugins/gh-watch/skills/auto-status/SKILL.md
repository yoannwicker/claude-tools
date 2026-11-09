---
name: auto-status
description: Superviser les watchers GitHub (review-watch, tidy-watch…) — timers actifs ou arrêtés, dernier et prochain passage, dépôts et modes, sessions lancées et quand (herdr, analyses en fond prêtes à reprendre), dernier rattrapage quotidien et actions manquées qui attendent, et sur demande l'historique des déclenchements (session lancée, notification, ignoré, en attente, échec) et ce qu'un passage ferait maintenant
argument-hint: "[--history] [--since <30m|24h|7d|date>] [--dry-run]"
disable-model-invocation: true
allowed-tools: Bash(gh-watch:*), Bash(command -v gh-watch)
---

Argument : `$ARGUMENTS`

Lecture seule : rien n'est lancé, activé ni repris.

`gh-watch` absent du `PATH` (`command -v gh-watch`) : dire qu'il s'installe avec le plugin
(`./install.sh plugin gh-watch` depuis claude-tools, ou avec `review` / `git-tidy` qui en
dépendent) et s'arrêter.

Historique et sessions herdr fermées affichés seulement avec `--history` (ou `--since`,
qui l'implique).

1. `gh-watch status --json --since <D>` (`D` : celui de l'argument, sinon `24h` ; avec
   `--dry-run` si l'argument le demande ; l'historique sert aussi à « ce qui cloche », même
   non affiché). Liste vide :
   aucun watcher déclaré (`~/.config/claude-tools/watchers.d/`) — rappeler qu'ils viennent
   de `./install.sh plugin review` et `./install.sh plugin git-tidy`, et s'arrêter.
2. Un tableau des watchers : nom, timer (`active` ou non), toutes les N min, dernier et
   prochain passage (heure locale `HH:MM`, date si ce n'est pas aujourd'hui).
3. Par watcher, ses dépôts : un tableau `dépôt` + une colonne par événement (`kinds`) avec
   le mode, plus les réglages en plus s'il y en a (`approvals`, `validation_status`,
   `test_env`) — une entrée `owner/*` vaut pour tous les dépôts du propriétaire sans
   réglage propre ; puis la ligne « dépôts non listés » (`default`, réglé par `auto * on`).
4. Les sessions, s'il y en a (sans `--history`, les sessions herdr `fermée` sont omises ;
   aucune restante : pas de section) : clé (`dépôt#n:événement`), titre, herdr ouverte/fermée ou
   analyse en fond (`running`, `ready`, `failed`, `resumed`), lancée quand (`launched`) et
   pour quel événement GitHub (`event_at`) ; pour `ready`/`failed`, la commande `resume` à
   lancer ; pour `failed`, le chemin du journal.
5. Avec `--history` seulement : les déclenchements depuis `D` (`history` de chaque watcher), tous watchers confondus, du
   plus récent au plus ancien : heure, watcher, `dépôt#n`, événement, action (`lancé`,
   `notifié`, `ignoré`, `en attente`, `échec`) et son détail. Aucun : le dire en une ligne
   (« aucun déclenchement depuis 24 h »).
6. Avec `--dry-run` : ce que chaque passage ferait maintenant (`dry_run`), tel quel.
7. Rattrapage quotidien : `gh-watch catchup --json` — une ligne : `board_auto` (on/off), dernier
   rattrapage (`last` : fini quand, par quel watcher, nombre de manquées ou erreur ; `null` :
   jamais). Off et jamais lancé : une ligne « rattrapage quotidien off
   (/gh-watch:board-auto on) ».
8. Ce qui cloche, en fin de réponse : watcher en erreur (`error`), timer arrêté alors qu'un
   dépôt est en `auto` (→ `<watcher> enable`), analyse échouée, déclenchement en `échec`,
   session prête oubliée depuis plus d'un jour, rattrapage en échec (`last.error`) ou
   `board_auto` on sans timer actif (`timers` faux), et les manquées qui attendent depuis
   plus d'un jour ouvré (`waiting` : `dépôt#n`, état, depuis combien de jours ouvrés, la
   commande `gh-watch launch`). Rien ne cloche : le dire en une ligne.
