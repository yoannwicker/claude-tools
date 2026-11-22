---
name: profile
description: Profils claude-profile dans Cursor — basculer cette session cursor-agent sur un autre profil en reprenant la conversation, voir un profil, choisir le profil par défaut ou celui du projet. À utiliser quand l'utilisateur tape /profile, demande de changer de profil, ou veut savoir sur quel profil tourne la session.
---

# /profile — profils de la session Cursor

Lancer les commandes indiquées telles quelles, puis montrer leur sortie (ou la résumer pour
une liste). Ne rien lancer d'autre.

| Appel | Commande |
|---|---|
| `/profile` | `claude-profile list && claude-profile cursor-current` : liste des profils (nom, description, état), et celui de cette session |
| `/profile show [<nom>]` | `claude-profile show <nom>` (sans nom : le profil de cette session, donné par `claude-profile cursor-current`) |
| `/profile default` | `claude-profile default` : profil par défaut |
| `/profile default <nom>` | `claude-profile default <nom>` (`reference` ou `--unset` : aucun) |
| `/profile project` | `claude-profile project` : profil du projet (dossier courant) |
| `/profile project <nom>` | `claude-profile project <nom>` (`--unset` : le retirer) |
| `/profile <nom>` | bascule, voir ci-dessous |

`default` et `project` valent pour les prochaines sessions lancées par `agent` (ou
`claude-profile cursor`) sans profil donné, et pour `claude` : pas pour cette session.

## Bascule : `/profile <nom>`

1. Lancer `claude-profile cursor-switch <nom>`, et rien d'autre dans ce tour.
2. Code 0 : dire en une ligne que la session se ferme et reprend sur `<nom>`. Ne plus rien
   lancer : cursor-agent se ferme une seconde plus tard, et `claude-profile cursor` relance la
   conversation sur le nouveau profil.
3. Code 3 (session lancée hors de `claude-profile cursor`, par exemple `agent` tapé dans un
   shell ouvert avant l'installation de la fonction) ou autre erreur : montrer le message tel
   quel ; il donne la commande de relance manuelle.
