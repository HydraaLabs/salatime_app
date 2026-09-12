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

## Artefact de production et Shorebird

- Sources de l’artefact : `70c3cbea41f4b3fe2bbcddcab7552ef5b53e672e`, poussé
  et relu sur `origin/main` avant la compilation.
- Flutter Shorebird 3.41.6, révision
  `76ca3dff01cc7c5e6978e6b51e442777c6930419`.
- AAB signé et validé par `jarsigner` et `bundletool` : 134 248 856 octets ;
  SHA-256 `f8d3a2b99fd5359dc2ca5e60e5cfe3936627d43330ab4c96711f45e9866a0222`.
- Manifeste : `net.salatime.app`, version 1.0.16, code 19, Android minimum 24,
  cible 36, sans mode debug. Architectures ARM 32 bits, ARM64 et x86_64.
- Les 68 sons Flutter et natifs et le catalogue Athkar sont identiques aux
  sources dans le bundle ; les deux récepteurs de notifications restent privés.
- Shorebird : release `826646`, Android `active`, artefact AAB `3665587`.
  Taille et empreinte relues par API et identiques au fichier local.

## Web et téléchargement Android

- Web : commit `406e142341d143ba26811e4843ef05e95eaa4584` poussé ; thème vert
  et bienvenue des nouveaux comptes installés avec sauvegarde ciblée.
- 71 tests Laravel et 54 052 assertions réussis. Accueil, page Fès,
  confidentialité et configuration des comptes : HTTP 200 ; routes protégées
  anonymes : HTTP 401. Les 121 fichiers publics du build ont le SHA attendu.
- La bienvenue HTML et texte est rendue par PHP en production avec le transport
  dédié. Aucun email de test ni email rétroactif envoyé pendant la publication.
- APK universel issu du même AAB : 157 724 602 octets ;
  SHA-256 `2b797137ce71bc668a9922dc8b3765ae39f9ce8cd9ffb583f0139de8824280c5`.
  Signature release vérifiée, SHA-1 certificat
  `00:84:E8:31:16:A0:5D:07:A9:37:0C:66:67:81:F3:05:BE:87:AA:70`.
- APK publié à `/dl/SalaTime-1.0.16-19.apk`, `/app-release.apk` et
  `/dl/salatime.apk`. Les trois téléchargements HTTPS complets sont conformes
  (HTTP 200, MIME APK, taille et SHA ci-dessus). Archives antérieures conservées.

## Google Play

- API Android Publisher : téléversement du même AAB, validation et commit de
  l’édition réussis. Relecture dans une nouvelle édition : production 1.0.16,
  code 19, statut `completed`, notes françaises et anglaises.
- SHA-256 du bundle relu sur Play identique au fichier local et à Shorebird.
  Pistes de test inchangées ; édition de contrôle supprimée avec HTTP 204.
- La piste production est confirmée ; la disponibilité publique et l’état
  exact de l’examen Google ne sont pas déduits de ce statut API.
- La demande ultérieure de suivi cloud Athkar/Coran arrive après ce commit
  Play et ne fait pas partie de l’artefact 1.0.16+19.
