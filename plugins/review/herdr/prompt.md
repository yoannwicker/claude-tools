Applique à cette PR le skill `/review:pr` du plugin review de Claude Code : lis
`@PLUGIN_DIR@/skills/pr/SKILL.md` et suis-le (`${CLAUDE_SKILL_DIR}` y vaut
`@PLUGIN_DIR@/skills/pr`), avec le numéro de PR et le head SHA vérifiés ci-dessus.
Étapes 1 à 3 telles quelles : agent `review:reviewer`, vérification de chaque constat,
validation point par point avec moi. Étape 4 : ne publie rien de toi-même ; montre la review
prête (synthèse et commentaires) et demande-moi (AskUserQuestion) si je veux la poster avec
`review-post`. Étape 5 telle quelle : supprimer le worktree et la branche créés pour cette
revue s'il y en a, après ma réponse à sa question. Seul mon accord explicite dans cette
conversation lève la consigne de lecture seule, pour cette publication et ce ménage
seulement.
