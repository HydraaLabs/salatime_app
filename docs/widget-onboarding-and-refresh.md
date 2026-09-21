# Widgets : choix initial et actualisation indépendante

Modifications locales postérieures à la publication 1.0.19+22.

Le premier lancement propose trois formats : petit 2 × 1, moyen 4 × 1 et
grand 5 × 2. Chaque choix radio possède un aperçu illustré ; le moyen est
présélectionné. Seul le bouton de confirmation demande l’ajout au lanceur.
La proposition reste facultative et unique. Les libellés sont disponibles
dans les dix langues, avec les couleurs de SalaTime.

Le widget pouvait rester sur « Ouvrez SalaTime pour actualiser » : ses données
natives n’étaient envoyées qu’après la programmation de toutes les alarmes.
Sur le Samsung, le fichier `salatime_prayer_widget.xml` était absent alors
qu’un widget était déjà ajouté.

`PrayerWidgetSync` calcule la fenêtre de 31 jours depuis les données locales
et les ajustements existants, sans demander de localisation, réseau ou
permission de notification. Il prépare les données avant l’ajout, depuis
l’assistant et les paramètres, et se déclenche séparément lors des demandes
d’actualisation. Le planificateur transmet aussi sa nouvelle fenêtre avant
d’enregistrer les alarmes. Une absence de données ne vide pas le cache natif.

La méthode native `updateWidget` ne modifie ni le manifeste d’alarmes ni les
réglages de silence automatique. La programmation complète garde son exécution
en arrière-plan et la synchronisation cloud reste inchangée.

Validation : 25 tests Flutter et 13 tests Android réussis, analyse sans anomalie.
Régressions couvertes : widget disponible avec notifications non initialisées,
enregistrement d’alarme bloqué, conservation du manifeste et des données
existantes, radios et confirmation, petit écran à 200 % en français/arabe.

APK de test signé et installé sur le Samsung SM-S901U le 13 septembre 2026 :
`/home/hemiad/Downloads/SalaTime-test-widget-refresh-1.0.19-22.apk`.
Package `net.salatime.app.preview`, SHA-256
`06148e7d0f11276c9fe0cbe79274723915adacac1ce7638f401a07c1dd399184`.
Après lancement, 155 horaires présents dans le cache natif. Le widget déjà
installé affiche Fès, Dohr, le compteur écoulé et les cinq horaires du jour.
Capture vérifiée : `/tmp/salatime-widget-refresh-samsung-home.png`.
Reçu : `/tmp/salatime-widget-refresh-device-audit.json`.
Ce correctif natif nécessite une future publication Android complète ;
il ne fait pas partie de la version 1.0.19+22 déjà envoyée à Google Play.

## Décompte à moins de 45 minutes

Les trois formats utilisent le rouge `#C62828` pour le décompte avant la
prochaine prière lorsque le temps restant est strictement inférieur à
45 minutes. À 45 minutes exactement, l’affichage reste vert `#2F5233`.
Le compteur du temps écoulé après une prière et l’affichage de l’heure sans
décompte gardent le vert. Les modes avec et sans secondes sont concernés.

Une actualisation native est programmée au franchissement du seuil, sans
dépendre d’un lancement de Flutter ni ajouter une actualisation chaque seconde.
Les actualisations existantes à l’heure de prière et à la fin des 90 minutes
de temps écoulé restent actives.

La même règle s’applique aux accueils classique et moderne de l’application.
Sur leurs fonds verts, le rouge clair `#FF8A80` préserve la lisibilité ; le
compteur écoulé conserve sa couleur blanche. Le minuteur existant effectue
la transition sans action de l’utilisateur.

Validation du seuil : 16 tests Android et 13 tests Flutter réussis, analyse
Dart sans anomalie. Les tests couvrent le seuil strict, la remise à la couleur
normale, l’actualisation native programmée et le passage automatique dans
l’application en thèmes clair et sombre.

Version de test avec ce seuil installée sur le Samsung :
`/home/hemiad/Downloads/SalaTime-test-countdown-red-1.0.19-22.apk`, SHA-256
`3e4de62e1f23b914bc96a77fe66ee44bc8f83387c3c5fe8b116d424ebf0fa7a9`.
Lancement réussi et compteur écoulé de Dohr vérifié dans l’application et
le widget. Le seuil rouge a été vérifié par les tests à heure simulée,
sans changer l’heure ou les horaires du téléphone. Reçu :
`/tmp/salatime-countdown-red-device-audit.json`. Aucune nouvelle publication.

Ces changements sont inclus dans la release 1.0.20+23. Voir
[le reçu de publication](release-1.0.20.md) pour les états des différents canaux.

## Règle commune révisée le 21 septembre 2026

Le temps écoulé s'affiche pendant une heure au maximum après la prière.
À 60 minutes exactement, l'accueil classique/moderne et les widgets Android/iOS
passent au décompte de la suivante. La priorité existante est conservée lorsque
la prochaine prière est déjà à une heure ou moins, même si la précédente a eu
lieu il y a moins d'une heure. Le compteur de notification Android suit la même
règle.

Le décompte garde sa couleur normale à `01:00:00` et devient rouge lorsque le
temps restant est strictement inférieur à une heure. Les actualisations natives
suivent ces nouveaux seuils ; le widget Android ne programme plus la fin du
compteur écoulé lorsque la prochaine prière a déjà pris sa place.

Exemple de la capture signalée : Assr à 16:40 et Maghrib à 19:18 donnent
`00:59:59` écoulé à 17:39:59, puis `01:38:00` avant Maghrib à 17:40.
À 18:06:37, le décompte est `01:11:23`. À 18:18:01, il devient rouge
avec `00:59:59` restantes.

Les régressions couvrent les seuils stricts, la transition automatique en thèmes
clair/sombre, les widgets avec/sans secondes, les prières rapprochées et minuit.
Ce changement est inclus dans les versions Android 1.0.26 (30) et iOS 1.0.26 (33).

Validation : 638 tests Flutter réussis, analyse sans anomalie et 42 tests
Android ciblés réussis (13 widgets, 29 notifications). Ces derniers utilisent
Flutter stable 3.41.8 via `-Pflutter.sdk` et son dépôt officiel, le SDK Shorebird
local ayant renvoyé des métadonnées Maven incompatibles en mode debug.
La configuration locale Shorebird est conservée. La compilation de production
Android repasse l'analyse et les 638 tests avec Shorebird Flutter 3.41.6. La
compilation iOS sur macOS réussit l'analyse, les 638 tests Flutter et la suite
XCTest comprenant les seuils et minuit. Pas de nouvel essai physique pour ce
correctif. Les deux versions sont soumises aux stores ; voir les
[preuves de publication et leurs limites](release-1.0.26.md).
