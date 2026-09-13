# SalaTime Android 1.0.20+23

Package de production : `net.salatime.app`.

## Modifications

Le premier lancement propose trois tailles de widget avec aperçu et boutons
radio ; le format moyen est présélectionné. Le widget reçoit désormais ses
horaires locaux indépendamment de la programmation des notifications, et avant
son ajout au bureau. Il conserve ses données lorsque le calcul est indisponible.

À moins de 45 minutes de la prochaine prière, le décompte devient rouge dans
les trois widgets et dans les accueils classique et moderne. L’actualisation
au seuil est automatique ; le temps écoulé après la prière garde sa couleur
normale. Les modes avec et sans secondes sont pris en charge.

## Préparation et validation

Le préflight distant du 13 septembre 2026 confirme Play production 1.0.19/code
22 et Shorebird Android actif 827067/1.0.19+22. La version 1.0.20+23 est libre.
Publication demandée explicitement après validation sur le Samsung.

Les 518 tests Flutter passent avec le SDK release Shorebird Flutter 3.41.6.
L’analyse globale ne signale aucune anomalie. Le test de changement de méthode
de calcul vérifie désormais que l’affichage se met à jour pendant l’attente
de l’initialisation des notifications, conformément au correctif des widgets.

La version de test incluant ces fonctionnalités a été installée sur le
Samsung SM-S901U : lancement et widget existant vérifiés, avec compteur écoulé
de Dohr. Le seuil rouge est testé avec des heures simulées en clair et sombre ;
l’heure et les horaires réels du téléphone n’ont pas été modifiés.

Les changements natifs nécessitent une release Android complète. Aucun
correctif Shorebird destiné aux anciennes versions n’est inclus dans cet envoi.

Les 156 tests Android natifs passent avec le SDK de test Flutter 3.41.8.
Le SDK Shorebird 3.41.6 reste épinglé pour l’AAB de production.
