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

## Artefacts et Shorebird

Commit source poussé et relu sur `origin/main` : `2dd0855e5f353fea92662388e0fb9f2051dbe1d5`.
Shorebird : release `827176`, Android actif, artefact `3667891`,
Flutter `76ca3dff01cc7c5e6978e6b51e442777c6930419` (3.41.6).

Le bundle distant a été téléchargé intégralement et comparé au fichier validé :
143366077 octets, SHA-256 `f4474c0b95602e1e3702289318e6b75896a3e8e01a2ab2d91c7acb28e9cf5ac6`.
Il cible Android 36, minimum 24, sur arm64-v8a, armeabi-v7a et x86_64.
Signature non debug, dix langues, 68 sons, 1 141 fichiers de traduction du Coran,
catalogue Athkar et méthode native `updateWidget` vérifiés dans le bundle.

L’APK universel est généré depuis ce même AAB : 167002088 octets,
SHA-256 `6ba9c5403a9c2533e54afdbf80e775ed68adaf3883ab2db74ae7318a3fb24af6`.
Signature de distribution directe vérifiée : `00:84:E8:31:16:A0:5D:07:A9:37:0C:66:67:81:F3:05:BE:87:AA:70`
(SHA-1, distinct du certificat Google Play App Signing).

Reçus : `/tmp/salatime-1.0.20-aab-verification.json`,
`/tmp/salatime-1.0.20-shorebird-verified.json` et
`/tmp/SalaTime-1.0.20-23.audit.json`.

## Google Play API

Le bundle identique est téléversé, la piste production validée puis commitée.
Une nouvelle édition de lecture confirme `1.0.20`, code `23`, statut API
`completed` et la même empreinte SHA-256. Les autres pistes sont conservées.
L’édition de vérification est supprimée avec HTTP204.
Reçu : `/tmp/salatime-play-1.0.20-publication.json`, phase `verified`.

La Console Play affiche 1.0.20 dans « Modifications en cours d’examen », avec
les vérifications rapides automatiques en cours et l’envoi pour examen à leur
issue. La publication gérée est désactivée ; aucune action d’envoi
supplémentaire n’est requise. Les déclarations Sécurité des données et services
de premier plan déjà soumises sont conservées. La disponibilité publique
Google Play n’est pas encore confirmée.
Capture textuelle : `/tmp/salatime-1.0.20-console-after.txt`.

## APK du site

Les trois URL ont été relues intégralement le 2026-09-13T13:14:09.394534+00:00 : HTTP200,
MIME APK, cache Cloudflare BYPASS et empreinte identique à l’APK signé.

- https://salatime.net/dl/SalaTime-1.0.20-23.apk
- https://salatime.net/dl/salatime.apk
- https://salatime.net/app-release.apk

Les deux alias précédents ont été sauvegardés ; huit chemins protégés
(archives et fichiers d’accès) sont restés identiques. Aucun backend ni
fichier de configuration n’a été déployé. Sauvegarde privée :
`/home/bshttdz/.salatime-apk-1.0.20-23-20260913T131210Z-09f4985bcea9`.

Reçus dans `/tmp/salatime-web-release-1.0.20-audit/` :
`apk-deployment-result.json`, `apk-public-readback.json` et `completion.json`.
