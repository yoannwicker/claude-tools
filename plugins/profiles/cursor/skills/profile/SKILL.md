---
name: profile
description: Basculer cette session cursor-agent sur un autre profil claude-profile (plugins Claude et surcharges Cursor du profil), en reprenant la même conversation. À utiliser quand l'utilisateur tape /profile, demande de changer de profil, ou veut savoir sur quel profil tourne la session.
---

# /profile — profil de la session Cursor

Argument : le nom du profil (`/profile lean`), ou rien.

## Sans argument

Lancer `claude-profile list` et `claude-profile cursor-current`, puis afficher la liste des
profils (nom et description) en indiquant celui de cette session. Ne rien basculer.

## Avec un nom de profil

1. Lancer `claude-profile cursor-switch <nom>`, et rien d'autre dans ce tour.
2. Code 0 : dire en une ligne que la session se ferme et reprend sur `<nom>`. Ne plus rien
   lancer : cursor-agent se ferme une seconde plus tard, et `claude-profile cursor` relance la
   conversation sur le nouveau profil.
3. Code 3 (session lancée hors de `claude-profile cursor`) ou autre erreur : montrer le
   message tel quel ; il donne la commande de relance manuelle.
