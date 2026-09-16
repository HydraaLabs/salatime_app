# SalaTime Android 1.0.22+25

Package de production : `net.salatime.app`. Publication autorisée après la
validation de SalaTime Test sur le Samsung, dans la nuit du 16 au 17 septembre.

## Changements

La méthode de calcul peut être sélectionnée automatiquement selon le pays de
la position ou de la ville choisie. Les choix manuels existants, l'école de
calcul et les corrections personnelles sont conservés. Une option Ramadan
propose Isha à 90 ou 120 minutes après Maghrib, uniquement pendant les nuits
du mois hégirien corrigé de l'application.

Android arme une fenêtre de trois jours calendaires et conserve une réserve
hors ligne allant jusqu'à 30 jours. Le renouvellement natif et la préparation
par lots réduisent le nombre d'alarmes et les écritures de programmation.
La réserve est prolongée à l'ouverture de l'application. Les notifications
de prière utilisent une priorité élevée tout en respectant le silence.

Les onze méthodes communes au moteur public Adhan de la référence ont été
alignées, avec vérification indépendante de 1 232 cas. La dépendance MIT est
conservée avec sa licence ; aucun code ou son propriétaire de la référence
n'est ajouté. Les corrections locales de décompte et de cycle de vie des
lecteurs du Coran présentes dans l'APK Samsung sont également incluses.

## Préflight et validation

Le préflight distant du 17 septembre confirme Play production 1.0.21/code 24
et Shorebird Android actif 833116/1.0.21+24. La version 1.0.22+25 est libre.
Git local et distant sont initialement sur `58bdd909fe5ac3b33cde094fd0303c8de9a85046`.
Le build de production conserve Shorebird Flutter 3.41.6.

Avant préparation de la release : 590 tests Flutter et 216 tests Android
réussis, analyse Flutter sans problème. Le Samsung SM-S901U, Android 12, a
reçu le réveil de test écran en veille et processus arrêté avec 948 ms de
retard. Le silence est respecté ; son audible et bannière ne sont pas
validés par cet essai. La rotation après minuit est observée : 45 réveils
de prière actifs pour 435 occurrences en réserve. Les détails et limites
sont dans [le compte rendu appareil](prayer-three-day-window-2026-09-16.md).

Les 590 tests Flutter passent également avec le SDK de publication Shorebird
Flutter 3.41.6 ; son analyse complète ne signale aucun problème.

Les états de publication seront ajoutés après relecture des résultats
distants. Les modifications iOS ne font pas l'objet d'une publication.
