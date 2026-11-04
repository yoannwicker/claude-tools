# Mode auto de review-watch (commun à /review:pr-auto et /review:feedback-auto)

`<kind>` est donné par le skill : `review` (`/review:pr-auto` : demande de review sur la PR
d'un autre → `/review:pr`) ou `feedback` (`/review:feedback-auto` : review d'un autre sur une
de mes PR → `/review:feedback`). Ne toucher qu'à ce `<kind>`.

`review-watch` (dans le `bin/` du plugin) surveille GitHub (timer systemd, toutes les 5 min par
défaut, `review-watch interval <min>` pour changer).
Par dépôt et par événement : **auto** (session lancée d'office : worktree et pane herdr s'il
tourne, sinon analyse en fond puis notification dont le clic reprend la session),
**notify** (notification seulement, son clic lance la session ; défaut des dépôts non
listés) ou **off**. Rien n'est jamais posté sans validation dans la session.

## Avec `interval [<minutes>]`

Fréquence du scan, commune aux deux événements : `review-watch interval [<minutes>]` (5 par
défaut ; sans nombre, affiche la valeur). Afficher la sortie en une ligne.

## Avec `on` ou `off`

Dépôt courant : `review-watch auto . on|off <kind>`. `off` remet le mode des dépôts non
listés (notifier), il ne coupe pas tout. Afficher la sortie en une ligne.

## Sans argument

1. `review-watch repos --json` : dépôts configurés et clones GitHub des espaces de travail
   de `cl` (`repo`, `path`, `review`, `feedback`).
2. Demander (`AskUserQuestion`, `multiSelect`, header « Auto ») quels dépôts ont `<kind>` en
   auto : une option par dépôt, ceux déjà en auto en premier et marqués « (actif) », le
   dépôt courant ensuite. Au-delà de 4 options : les 3 premières plus « Autres… » ; dans ce
   cas, montrer d'abord la liste numérotée complète et accepter des numéros ou noms en
   texte libre.
3. Pour chaque dépôt dont l'état change : `review-watch auto <repo> on|off <kind>`.
4. Récapitulatif : `review-watch status`.

## Dans les deux cas

Si `status` (ou la sortie de `auto`) dit la surveillance arrêtée et qu'au moins un dépôt est
en auto, proposer `review-watch enable` (`AskUserQuestion`, header « Surveillance ») et le
lancer sur accord : il enregistre ce qui est déjà en attente sans rien lancer, puis active
le timer.
