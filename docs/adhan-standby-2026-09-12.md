# Correctif de l’adhan en veille — APK de test 1.0.13+16

## Problème observé

La capture Samsung du 12 septembre montre les notifications « avant l’adhan »,
As-sobh et Iqama toutes reçues à 06:02, alors que la prière était prévue à 05:36.
L’utilisateur signale un simple bip au déverrouillage. Cela établit un retard
de livraison de 26 minutes ; sans journaux du téléphone, la cause exacte du
blocage système reste à confirmer.

## Comportement corrigé

- Alarme Android `setAlarmClock` pour l’adhan principal, avec un raccourci
  qui ouvre l’app. Rappels en mode exact pendant la veille lorsque permis.
- Lecture native complète du son choisi, volume des alarmes, bouton Arrêter,
  libération des ressources à la fin/annulation/erreur/perte de priorité audio.
- Respect des canaux muets, du volume nul, des appels et du refus de priorité.
- Au-delà de deux minutes de retard, avis d’adhan silencieux avec heure prévue
  et suppression des rappels dépassés. Protection contre les doublons et
  les livraisons d’alarmes annulées ou reprogrammées.
- Transfert immédiat de chaque alarme pendant le renouvellement du calendrier,
  pour éviter de doubler temporairement les 450 alarmes en attente.
- Test programmé une minute plus tard, annulable, dans « Alarmes à venir » ;
  affichage du volume, des autorisations et du dernier retard mesuré.

## Validation

- Analyse Flutter : aucun problème.
- Tests Flutter : 79 réussis, dont le renouvellement de 450 alarmes avec une
  limite simulée de 500, le test différé, l’annulation et le retour des réglages.
- Tests Android Robolectric : 36 réussis, dont les nouveaux cas SDK 24/33 de
  retard de 26 minutes, lecture, arrêt, priorité refusée et volume nul.
- Interface française contrôlée à 360 × 800 et taille du texte × 1,5.
- APK release signé, Android 24 minimum / cible 36, arm64-v8a, armeabi-v7a,
  x86_64. Manifest, classes natives, ressources et empreintes des sons vérifiés.
- Aucun appareil connecté. Le test d’une minute ne valide pas une nuit de
  veille : le prochain adhan sur le Samsung reste à confirmer.

## Livraison pour essai

- Construction : Flutter 3.41.8, `flutter build apk --release --no-pub`.
- Version : `1.0.13+16`, paquet `net.salatime.app`.
- Taille : **92 233 096 octets**, identique dans le fichier local et les
  métadonnées relues sur Google Drive.
- SHA-256 local : `f6db1d38a1571cf6eb724c2aab0035d7d79b1681d317238c4077b0013a917431`.
- [APK sur Google Drive](https://drive.google.com/file/d/1kxI6MQuN41FMpsOB6qtE3tGSK_Gzqvpt/view?usp=drivesdk).

Installer l’APK, ouvrir SalaTime puis les réglages des notifications,
**Alarmes à venir → Tester dans une minute**. Verrouiller le téléphone et
attendre sans rouvrir l’app. Vérifier aussi le prochain adhan après une longue
veille et les restrictions de batterie Samsung indiquées dans cet écran.

Cette livraison concerne l’APK de test. Aucun envoi de cette version 1.0.13+16
à Google Play ou Shorebird n’a été réalisé. Les changements natifs exigent
un nouvel APK/AAB ; un patch Dart seul ne les distribue pas.
