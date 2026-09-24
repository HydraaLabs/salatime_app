# SalaTime 1.0.27 — suivi des déplacements

Source applicative : `e8b1df346eb33a4fc42c5a9db0bb37b9ef8f2008`.
Android : `1.0.27+31`. iOS : `1.0.27 (35)`.

## Comportement

Le suivi est facultatif et se configure dans les réglages de prière sur les
deux plateformes. Un déplacement d'environ 3 km recalcule les horaires et
actualise les rappels et les données des widgets. Une ville choisie
manuellement ou la désactivation du suivi arrête l'abonnement de localisation.
Le service réévalue les autorisations au retour dans l'application.

Android utilise un service de localisation au premier plan lorsque l'accès
en arrière-plan est autorisé, avec une notification dédiée qui explique
comment arrêter le suivi. L'autorisation limitée à l'utilisation n'active pas
ce service. Les adhans conservent leurs notifications et leur service audio.
iOS utilise les indicateurs et autorisations du système ; son écran explicatif
présente un bouton neutre « Suivant ». Le suivi n'est pas imposé à l'accueil.

## Vérifications effectuées

- 668 tests Flutter passés avant le build Android.
- AAB Shorebird 3.41.6 vérifié : version, signature, trois ABI, ressources,
  service de localisation privé et permission correspondante.
- SHA-256 de l'AAB :
  `099f40150dd0e711f2da7b6491395fad1ae2552aecc4c824ebc3332b336b5300`.
- Tablette Android émulée, paquet dérivé de cet AAB avec signature de test :
  activation explicite, autorisation, notification et service actifs hors de
  l'application, mise à jour de Fès vers Azrou après positions simulées,
  arrêt du service et retrait de sa notification après désactivation.
- Le choix manuel de Makkah arrête aussi le suivi ; la position simulée
  suivante ne remplace pas cette ville.
- Vidéo continue de ce test : 69,205 secondes, 1280 × 800, sans audio,
  simple remux MP4 faststart, sans modification des images.
  SHA-256 : `06b3e26e2bf70787075bf0e21b1ad3f2d5fb017045006771ef4ce2d9b4ce61f9`.

Ces contrôles Android ne constituent pas un essai sur Samsung physique,
ni une preuve de déplacement réel. L'émulateur a été arrêté après les essais.

## Distribution — état du 24 septembre 2026 (UTC)

- Code poussé sur GitHub.
- Release Android Shorebird `1.0.27+31` créée ; ce n'est pas un patch OTA.
- Google Play : bundle 31 chargé, notes FR/EN/AR enregistrées, release en
  brouillon. L'API accepte la validation du brouillon, mais refuse le passage
  en production avec HTTP 403 : nouvelle déclaration des services au premier
  plan requise. Les deux éditions API de promotion ont été supprimées après
  l'échec, sans commit de publication. L'ancienne release reste en place.
- La documentation Google impose la Console pour déclarer une nouvelle
  permission sensible. L'utilisateur demande de privilégier l'API ; aucune
  nouvelle manipulation de la Console après cette instruction, en attente
  d'une éventuelle exception pour cette seule déclaration.
- iOS : run GitHub `36065913929`, deuxième tentative réussie après un délai
  dépassé au démarrage du test runner lors de la première tentative. Les 668
  tests Flutter et l'étape de tests natifs passent. Archive signée et widget
  vérifiés ; transfert Apple accepté le 24 septembre à 23:07:26 UTC.
  Upload Apple `791abfee-1fdf-4cd8-b0b9-a1ed31a7ce04` : `COMPLETE`,
  build `VALID`, sans erreur ni avertissement. Le build 35 est rattaché à la
  version 1.0.27 (`PREPARE_FOR_SUBMISSION`, publication après approbation).
  Notes d'examen actualisées ; 36 captures, trois localisations et coordonnées
  de démonstration préservées. Apple refuse le champ `whatsNew` à ce stade
  de première publication : les propositions FR/EN/AR restent locales.
- Le paquet privé iPhone 35 a été produit par le run `36071218818`, déchiffré
  et vérifié localement. Code et ressources inchangés par la re-signature.
  Le secret temporaire GitHub et sa copie locale ont été supprimés.
  Installation non effectuée : l'iPhone n'était plus connecté en USB.
  Aucun test physique ni capture iPhone du build 35 n'est revendiqué.
- Apple exige une nouvelle vidéo sur appareil physique montrant le suivi
  de localisation en arrière-plan (2.5.4). La vidéo Android émulée ne peut
  pas remplacer cette pièce. La nouvelle soumission Apple reste à effectuer ; le dossier d'examen
  antérieur reste `UNRESOLVED_ISSUES`. Aucun envoi d'une nouvelle vidéo,
  résolution de ces problèmes ou nouvelle soumission n'a été déclaré fait.

Les journaux, reçus API et la vidéo sont conservés dans le dossier local ignoré
`release-artifacts/release-1.0.27/`. Les coordonnées et identifiants du compte
de démonstration Apple ne sont pas inclus dans ce document.

Références :
- [Compilation iOS](https://github.com/HydraaLabs/salatime_app/actions/runs/36065913929)
- [Déclarations de permissions Google Play](https://support.google.com/googleplay/android-developer/answer/9214102?hl=en)
