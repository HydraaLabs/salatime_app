# Choix de la méthode de calcul

Ajout local du 12 septembre 2026, sans publication Git, Play ou Shorebird.

## Interface

Dans Paramètres → Paramètres de l’heure de prière → Méthode de calcul, une page dédiée présente 23 méthodes avec leurs noms complets, une coche de sélection et un retour après sauvegarde. Les méthodes de la capture sont placées en premier ; les autres choix existants, dont Maroc, France, Algérie et Tunisie, restent disponibles. Les dix langues de l’application disposent des nouveaux libellés. Le thème SalaTime, les deux modes clair/sombre et les grandes tailles de texte sont conservés.

Les identifiants restent ceux déjà utilisés par les horaires et la sauvegarde cloud : `0` à `23`, sauf `6`. Le choix mémorisé est conservé ; une valeur absente ou inconnue utilise le défaut existant Karachi (`1`). Les noms ont été rapprochés de la [documentation du catalogue Aladhan](https://aladhan.com/calculation-methods). Dubaï (`16`) et Région du Golfe (`8`) restent deux conventions distinctes ; Dubaï n’est pas présenté comme une certification d’une autorité officielle.

## Application des réglages

La sélection valide et enregistre le choix localement, signale une modification au service cloud et demande une actualisation passive. La réponse de l’écran n’attend ni le réseau ni la programmation des alarmes. La synchronisation conserve son délai d’une minute après le dernier changement ; le planificateur regroupe les changements rapprochés et actualise les horaires, alarmes et données des widgets à partir des mêmes préférences.

Les écritures de méthode sont sérialisées. Une révision de calcul empêche une requête plus ancienne de réafficher des horaires obsolètes après un changement. Si le processus n’a pas encore préparé son contexte de calcul, il le restaure depuis les coordonnées enregistrées et le fuseau du téléphone, sans nouvelle demande de GPS. Les horaires d’une ville fournis sous forme de tableau manuel restent autoritaires : le choix peut être mémorisé, mais ne remplace pas ce tableau et conserve son identité de cache. Une notice explique ce cas dans la page de sélection.

La clé des tableaux manuels est désormais indépendante de la méthode et de l’école. Une lecture de compatibilité retrouve les entrées enregistrées par les anciennes versions pour la même ville, date, coordonnées et zone horaire. Le changement de méthode suivi d’un redémarrage conserve donc aussi ces horaires hors ligne, sans effacer les anciens caches.

Les coefficients astronomiques et les formats d’API n’ont pas changé. Aucun ajout au backend ou au schéma cloud n’est nécessaire pour ces 23 identifiants.

## Validation

Les tests de calcul existants comparent 736 journées de référence, sur 23 méthodes, deux écoles et quatre villes, et couvrent les fuseaux et changements d’heure. Cette comparaison est une régression du moteur existant ; elle ne démontre pas une identité des horaires avec une autre application ou avec un calendrier officiel local.

Les contrôles de cette intervention couvrent également la sélection et la persistance, les coordonnées sauvegardées, les horaires manuels, les erreurs d’écriture, le rendu multilingue et la sauvegarde cloud différée. La validation physique et la publication sont rapportées séparément du résultat des tests locaux.

Résultat : **117 tests réussis**, répartis en 84 tests de régression (accueil, cache, calculs, alarmes, synchronisation), 15 tests du choix et de la persistance, et 18 tests d’interface. Analyse Dart ciblée sur huit fichiers sans problème ; JSON des dix langues valides ; `git diff --check` réussi. Aperçus normaux et grande police dans `/tmp/salatime-calculation-methods-qa/`.

## APK de test

[SalaTime-test-methodes-calcul-1.0.15-18.apk](/home/hemiad/Downloads/SalaTime-test-methodes-calcul-1.0.15-18.apk), SHA-256 `ae618e24d8e611bab59fd6a86b555c9d02bf0dd18b4e91ea7824408c7e76102a`. Compilation debug avec demande arm64, package `net.salatime.app.preview`, API habituelle `https://salatime.net`, même signature debug. L’APK a été installé avec `adb install -r` sur le Samsung SM-S901U reconnecté : résultat `Success`, données de l’application conservées, version Play distincte préservée. Aucun push ni publication Play/Shorebird.

Le lancement de SalaTime Test et l’accès à la page « Méthode de calcul » ont été constatés dans la hiérarchie Android, avec les noms complets et Karachi toujours coché. Aucun autre choix n’a été appliqué pendant cette inspection. L’utilisateur ayant repris la navigation sur le téléphone, les interactions ont été arrêtées ; les rendus visuels contrôlés restent ceux des tests Flutter, et aucun déclenchement d’alarme physique n’est revendiqué. Les fichiers temporaires d’inspection ont été supprimés.
