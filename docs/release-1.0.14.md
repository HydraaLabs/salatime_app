# Publication Android 1.0.14+17 — 12 septembre 2026

- Application : SalaTime (`net.salatime.app`).
- Sources : commit `0e8cb2d1f7af7fc01edc33aa5ef06ca81f979031`.
- Déclenchement de l'adhan par une alarme Android de type réveil, lecture du son complet dans un service temporaire et protection du passage du récepteur au lecteur contre la mise en veille.
- Restauration des alarmes futures après redémarrage ou mise à jour ; les rappels expirés ne déclenchent pas de son au déverrouillage.
- Test de l'adhan à une minute et diagnostic des permissions, du volume des alarmes et du dernier retard observé.
- Comparaison du code de deux applications open source et limites détaillées dans [l'audit de fiabilité](prayer-background-reference-audit-2026-09-12.md).
- Cette publication distribue les nouveaux composants Android dans une version complète. Ils nécessitent l'installation de la mise à jour ; aucun patch ne les ajoute aux anciennes versions.

## Validation et bundle

- Flutter Shorebird `3.41.6`, révision `76ca3dff01cc7c5e6978e6b51e442777c6930419`.
- Construction : `shorebird release android --flutter-version 3.41.6 --build-name 1.0.14 --build-number 17 --no-confirm`.
- Les 79 tests Flutter passent de nouveau avec ce SDK de publication. Les 44 tests Android Robolectric ont réussi sur ces mêmes sources avant publication, notamment le relais du verrou de veille, le démarrage refusé ou retardé du service et la restauration des alarmes.
- Analyse Flutter avec le SDK de publication : aucune anomalie.
- Manifeste du bundle vérifié : paquet `net.salatime.app`, version `1.0.14`, code `17`, SDK minimum `24`, cible `36` ; service `mediaPlayback` et récepteurs attendus présents.
- Signature vérifiée avec `jarsigner`, structure validée avec `bundletool validate` ; même certificat que les APK précédents.
- Certificat SHA-256 : `8b1d9367a52f773831b10a42eda05e9ba6802cb4c30699a285764bbb281b507b`.
- Présence vérifiée des quatre classes natives de programmation, réception, lecture et protection de veille ; contenu des trois sons d'adhan comparé par SHA-256.
- AAB : `build/app/outputs/bundle/release/app-release.aab`, **83 832 993 octets**.
- SHA-256 : `425c9008ce454d382a4b09af8db203f122780b6f38d36e2a49e931fa7bd6f705`.
- Copie conservée pour l'envoi Play : `/tmp/SalaTime-1.0.14-17-shorebird.aab`.

Les tests automatisés ne constituent pas une validation sur le Samsung de
l'utilisateur. La réception après une veille prolongée reste à vérifier sur
appareil. La programmation couvre jusqu'à 30 jours et se renouvelle à
l'ouverture/reprise de l'app et aux changements de réglages.

## Shorebird

- Application : `53488219-9639-4aac-87fc-72812320f340` ; release : **`825865`**.
- Relecture API : version `1.0.14+17`, plateforme Android `active`.
- Artefact distant `3662049` : taille et SHA-256 identiques au bundle local.

## Google Play

- Téléversement du même AAB par Android Publisher API : versionCode `17` et SHA-256 concordants.
- Mise à jour de la piste production, validation et commit réussis, avec notes de version en français et en anglais.
- Relecture dans une nouvelle édition : release `1.0.14`, `versionCodes: ["17"]`, statut `completed` ; empreinte du bundle identique. Pistes de test inchangées, comparaison avant/après effectuée.
- Vérification dans la [Play Console](https://play.google.com/console/u/0/developers/7420825427751299463/app/4975975602183880629/publishing) : `1.0.14` apparaît sous « Modifications en cours d'examen », avec l'action « Lancer le déploiement complet ».
- Les vérifications rapides automatiques sont en cours ; la Console indique que l'envoi pour examen suit automatiquement leur fin. Il n'y a pas d'action manuelle supplémentaire à envoyer dans cet état.
- Publication gérée désactivée : diffusion automatique après approbation Google. La disponibilité publique de `1.0.14` n'est pas encore confirmée ; la Console affiche le 8 septembre 2026 comme dernière publication.
