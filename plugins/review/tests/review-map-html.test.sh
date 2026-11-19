#!/usr/bin/env bash
# Tests de review-map-html : bash plugins/review/tests/review-map-html.test.sh
# Carte et diff d'exemple ; rien n'est ouvert ni publié.
set -u
bin=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/review-map-html
fails=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

check() { # check <libellé> <attendu> <obtenu>
  if [ "$2" = "$3" ]; then printf 'ok    %s\n' "$1"
  else printf 'FAIL  %s (attendu : %s, obtenu : %s)\n' "$1" "$2" "$3"; fails=$((fails + 1)); fi
}
has() { grep -qF -- "$1" "$tmp/out.html" && echo oui || echo non; }

cat > "$tmp/diff.patch" <<'EOF'
diff --git a/src/Remise.java b/src/Remise.java
--- a/src/Remise.java
+++ b/src/Remise.java
@@ -10,3 +10,3 @@ class Remise {
-  int taux;
+  int tauxArrondi; // COMPORTEMENT
   String code;
@@ -40,2 +40,2 @@ class Remise {
-  Discount d;
+  Remise d; // RENOMMAGE
diff --git a/db/V42.sql b/db/V42.sql
--- /dev/null
+++ b/db/V42.sql
@@ -0,0 +1 @@
+ALTER TABLE remise ADD taux INT NOT NULL; -- SQL
EOF
cat > "$tmp/carte.json" <<'EOF'
{"cible": "PR #7", "resume": {"besoin": "arrondir <les> remises", "livre": "fait", "pas_fait": null},
 "stats": {"ajouts": 3, "suppressions": 2, "fichiers": 2, "a_relire": 3, "bruit": 2},
 "endpoints": [{"methode": "POST", "chemin": "/remise", "changement": "ajoute", "detail": "nouveau", "fichier": "src/Api.java", "ligne": 3}],
 "donnees": {"base": [{"type": "colonne", "changement": "ajoute", "detail": "remise.taux NOT NULL", "fichier": "db/V42.sql", "ligne": 1}], "infra": []},
 "fonctionnalites": [{"id": "f1", "nom": "Calcul des remises", "risque": "moyenne", "ajouts": 1, "suppressions": 1,
   "fonctionnel": {"avant": "27,00", "apres": "26,99", "exemple": "PROMO10"}, "technique": "arrondi",
   "tests": {"couvrent": [], "non_couvert": ["cumul"]}, "risques": [{"risque": "cache", "niveau": "moyenne"}]}],
 "hunks": [{"id": "h1", "fichier": "src/Remise.java", "debut": 10, "fin": 11, "nature": "comportement", "couche": "domaine", "fonctionnalite": "f1", "resume": "arrondi"},
           {"id": "h2", "fichier": "src/Remise.java", "debut": 40, "fin": 41, "nature": "renommage", "couche": "domaine", "fonctionnalite": null, "resume": "renommage"},
           {"id": "h3", "fichier": "db/V42.sql", "debut": 1, "fin": 1, "nature": "migration", "couche": "sql", "fonctionnalite": "f1", "resume": "colonne taux"}],
 "refactorings": [], "hibernate": [{"entite": "Remise", "changements": [{"champ": "taux", "avant": "nullable", "apres": "NOT NULL"}]}],
 "ticket": [{"critere": "arrondi au centime", "statut": "fait", "ou": ["src/Remise.java:11"]}],
 "bruit": [{"nature": "renommage", "detail": "Discount → Remise", "lignes": 2}]}
EOF

"$bin" "$tmp/carte.json" "$tmp/diff.patch" "$tmp/out.html" >/dev/null
check "page écrite" oui "$([ -s "$tmp/out.html" ] && echo oui || echo non)"
check "texte échappé" "oui non" "$(has 'arrondir &lt;les&gt; remises') $(has 'arrondir <les> remises')"
check "endpoint et base dans le résumé" "oui oui" "$(has 'POST /remise') $(has 'remise.taux NOT NULL')"
check "sections présentes (SQL, Hibernate, Ticket, Bruit)" "oui oui oui oui" \
  "$(has 'id="sql"') $(has 'id="hibernate"') $(has 'id="ticket"') $(has 'id="bruit"')"
check "pas de section refactoring vide" non "$(has 'id="refactoring"')"
# Diffs embarqués (tableau JSON) : la fonctionnalité n'a que ses hunks hors bruit
diffs=$(sed -n 's/^const diffs = \(.*\);$/\1/p' "$tmp/out.html")
check "diff de la fonctionnalité : comportement et SQL, sans le renommage" "true true false" \
  "$(jq -r '.[0] | "\(contains("COMPORTEMENT")) \(contains("-- SQL")) \(contains("RENOMMAGE"))"' <<<"$diffs")"
check "bruit replié dans sa section" true "$(jq -r '.[-1] | contains("RENOMMAGE")' <<<"$diffs")"
# Segmentée : le sommaire liste chaque section, dans l'ordre, et le script n'en affiche qu'une
check "sommaire = sections, dans l'ordre" \
  "$(grep -o '<section id="[^"]*"' "$tmp/out.html" | sed 's/.*id="//; s/"$//' | paste -sd' ')" \
  "$(grep -o '<a href="#[^"]*"><span>' "$tmp/out.html" | sed 's/.*#//; s/".*//' | paste -sd' ')"
check "risque de la fonctionnalité dans le sommaire" oui "$(has '<span>Calcul des remises</span><span class="n r-moyenne">moyenne</span>')"
check "une section à la fois" "oui oui" "$(has 's.hidden = j !== i') $(has 'hashchange')"
check "usage sans arguments → erreur" 1 "$("$bin" >/dev/null 2>&1; echo $?)"

[ "$fails" = 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
