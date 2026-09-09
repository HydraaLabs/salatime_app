# Publication Android 1.0.11+14 — 9 septembre 2026

- Application : SalaTime (`net.salatime.app`).
- Sources : commit `758b69f95969159f216dffb084d2838a92750e32`, avec version portée à `1.0.11+14`.
- Les choix clair, sombre et automatique sont directement visibles dans les paramètres, avec application immédiate et mémorisation.
- Les notifications Android utilisent des canaux sans badge. Les anciens canaux sont retirés après reprogrammation des rappels, en préservant leurs réglages ; une erreur de programmation empêche leur suppression.
- Les changements natifs iOS présents dans les sources ne sont pas distribués par cette publication Android.

## Validation

- Analyse Flutter : aucune anomalie ; suite complète : 56 tests réussis sur les sources avant le changement de numéro de version.
- Construction réussie avec `shorebird release android --flutter-version 3.41.6 --build-name 1.0.11 --build-number 14 --no-confirm`.
- Manifeste du bundle : `net.salatime.app`, version `1.0.11`, code `14` ; signature vérifiée avec `jarsigner`.
- AAB : `build/app/outputs/bundle/release/app-release.aab`, 82 729 709 octets.
- SHA-256 : `d19b0d092e4ddd4c496b234c96c9698974d08cdb585222d0c28f8d9b8abdfe50`.

## Shorebird

- Application : `53488219-9639-4aac-87fc-72812320f340` ; release : `820484`.
- Relecture API : version `1.0.11+14`, plateforme Android `active`.
- Taille et empreinte du bundle distant identiques au fichier local.

## Google Play

- Publication par Android Publisher API sur la piste production, avec notes de version en français et en anglais.
- Téléversement du bundle, contrôle SHA-256, validation et commit réussis.
- Relecture dans une nouvelle édition : release `1.0.11`, `versionCodes: ["14"]`, statut `completed`.
- Le statut de piste confirme la soumission en production. L'état de l'examen Google et la disponibilité publique n'ont pas été vérifiés dans la Console.
- La disparition du badge sur le téléphone de l'utilisateur reste à vérifier après installation et ouverture de la mise à jour.
