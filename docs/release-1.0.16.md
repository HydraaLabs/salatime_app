# SalaTime Android 1.0.16+19

Application de production : `net.salatime.app`.

## Contenu

- Lecteur de zikr hors ligne : 218 invocations, 14 catégories, textes arabes,
  références et répétitions, réglage de taille et compteurs de session. Entrée
  Zikr dans les deux barres de navigation ; dhikrs personnels conservés dans Plus.
- Menu du bas limité à Qibla, Zikr, Mosquées et Plus. L’accueil reste l’écran
  initial ; flèches et retour système y ramènent depuis les quatre rubriques,
  avec conservation des pages visitées et pause du capteur Qibla.
- Configuration des sons et notifications par prière et par phase, bibliothèque
  de 68 sons, rappels complémentaires et import de sons personnels.
- Connexion Google et email ; synchronisation des préférences une minute après
  le dernier changement. Reprogrammation passive des alarmes en arrière-plan.
- Méthodes de calcul et ajustements horaires configurables, affichage cohérent
  entre prières, rappels et widgets, y compris au passage de minuit.
- Qibla et widgets enrichis ; affichage du temps écoulé depuis une prière pendant
  90 minutes. Palette verte harmonisée et thèmes clair, sombre et automatique.
- Apparence repliable, événements passés grisés, bandeau technique retiré de
  l’accueil. Corrections de débordement et protection des récepteurs Android.

## Validation avant publication

- Analyse Flutter globale sans anomalie avec le SDK de publication.
- 367 tests Flutter réussis avec le SDK Shorebird Flutter 3.41.6, dont les
  15 tests du lecteur et les 10 tests de navigation et de retour à l’accueil.
- 89 tests Android natifs réussis avant l’ajout du lecteur et des retours
  (aucune modification native ensuite).
- Catalogue Athkar : 12 tests réussis ; 14 catégories, 218 identifiants uniques,
  textes et références conservés, lectures hors ligne et erreurs contrôlées.
- Le modèle horaire de base reste intact lors des ajustements. Vérification sur
  Samsung de +1 puis −1 minute sur Assr, avec restauration des préférences.
- Les contrôles automatisés des alarmes vérifient leur planification ; ils ne
  prouvent pas tous les déclenchements en veille sur chaque modèle de téléphone.
- Prévisualisation 1.0.16+19 installée avec conservation des données sur le
  Samsung SM-S901U dans `net.salatime.app.preview`. Menu à quatre rubriques,
  lecteur et flèche Zikr constatés à l’écran. Les retours des quatre rubriques
  sont couverts par les tests ; aucun essai de veille supplémentaire effectué.
- APK de prévisualisation construit avec Flutter 3.41.8 ; SHA-256
  `c3aa3ece75844102eddb6e0d3ba75c30b724a694a198d0401af0e33b827ac0dc`.
  Le SDK de publication 3.41.6 reste utilisé pour les tests et la release.

Les preuves de compilation, signatures et publications sont ajoutées après
vérification des artefacts et relecture des services distants.
