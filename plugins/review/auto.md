# Mode auto de review-watch (commun à /review:pr-auto et /review:feedback-auto)

`<kind>` est donné par le skill : `review_requested` (`/review:pr-auto` : demande de review
sur la PR d'un autre → `/review:pr`) ou `feedback_received` (`/review:feedback-auto` : retours
d'un autre sur une de mes PR → `/review:feedback`). Ne toucher qu'à ce `<kind>` (clé
`on_<kind>` de la config).

`review-watch` (dans le `bin/` du plugin) surveille GitHub (timer systemd, toutes les 5 min par
défaut, `review-watch interval <min>` pour changer).
Par dépôt et par événement (section `watcher` de `~/.config/claude-tools/review.json`) :
**auto** (session lancée d'office : worktree et pane herdr s'il tourne, sinon analyse en
fond puis notification dont le clic reprend la session), **notify** (notification
seulement, son clic lance la session) ou **off** (rien de réglé : off). Rien n'est jamais
posté sans validation dans la session.

## Avec `interval [<minutes>]`

Fréquence du scan, commune aux deux événements : `review-watch interval [<minutes>]` (5 par
défaut ; sans nombre, affiche la valeur). Afficher la sortie en une ligne.

## Avec `on` ou `off` [`<cible>`]

`review-watch auto <cible> on|off <kind>`, cible `.` (dépôt courant) par défaut, sinon
celle donnée : `owner/repo`, `owner/*` (tous les dépôts du propriétaire, ex.
`softwarevidal/*`) ou `*` (tous les dépôts). Le réglage le plus précis l'emporte : dépôt,
puis `owner/*`, puis `*`. `off` remet le niveau au-dessus (au bout, off), il ne coupe pas
tout ; pour exclure un dépôt d'un `owner/*` ou `*` en auto : `review-watch add <repo>
--on-<kind avec des tirets> notify` (ou `off`). Afficher la sortie en une ligne.

## Sans argument

1. `review-watch repos --json` : dépôts configurés et clones GitHub des espaces de travail
   de `cl` (`repo`, `path`, `review_requested`, `feedback_received` : le mode de chacun).
2. Demander (`AskUserQuestion`, `multiSelect`, header « Auto ») quels dépôts ont `<kind>` en
   auto : une option par dépôt, ceux déjà en auto en premier et marqués « (actif) », le
   dépôt courant ensuite. Au-delà de 4 options : les 3 premières plus « Autres… » ; dans ce
   cas, montrer d'abord la liste numérotée complète et accepter des numéros ou noms en
   texte libre.
   Les entrées `owner/*` et `*` de la config y figurent aussi ; rappeler sous la
   question que `on owner/*` ou `on *` active tout un propriétaire ou tous les dépôts.
3. Pour chaque dépôt dont l'état change : `review-watch auto <repo> on|off <kind>`.
4. Récapitulatif : `review-watch status`.

## Dans les deux cas

Si `status` (ou la sortie de `auto`) dit la surveillance arrêtée et qu'au moins un dépôt est
en auto, proposer `review-watch enable` (`AskUserQuestion`, header « Surveillance ») et le
lancer sur accord : il enregistre ce qui est déjà en attente sans rien lancer, puis active
le timer.
