# Publication Android 1.0.10+13 — 9 septembre 2026

- Application : SalaTime (`net.salatime.app`).
- Sources : optimisations du commit `2128753dfade4a49563797f69119bc0727711381`, avec version portée à `1.0.10+13`.
- Construction : `shorebird release android --flutter-version 3.41.6 --build-name 1.0.10 --build-number 13 --no-confirm`.
- Flutter Shorebird : révision `76ca3dff01cc7c5e6978e6b51e442777c6930419`.

## Vérifications

- `flutter analyze` : aucune anomalie, avec le SDK Flutter utilisé pour la release.
- `flutter test` : 48 tests réussis avec ce même SDK.
- Manifeste AAB vérifié : package `net.salatime.app`, version `1.0.10`, code `13`, SDK minimum 24, SDK cible 36.
- Signature AAB vérifiée avec `jarsigner`.
- AAB : `build/app/outputs/bundle/release/app-release.aab`, 82 722 795 octets.
- SHA-256 : `d53e043e510faaf214c0e577a76aa5d75f9efd7be5c2bbef2ef5247d1f9c63c4`.

## Shorebird

- Application `53488219-9639-4aac-87fc-72812320f340`, release `820146`.
- Version `1.0.10+13` publiée ; relecture API : plateforme Android `active`.
- L'artefact AAB distant possède exactement la taille et le SHA-256 du bundle local.

## Google Play

- Publication effectuée via Android Publisher API : téléversement du bundle, mise à jour de la piste production, validation, puis commit de l'édition.
- Code reçu lors du téléversement : `13` ; SHA-256 retourné identique au bundle local et à Shorebird.
- Relecture dans une nouvelle édition : piste `production`, release `1.0.10`, `versionCodes: ["13"]`, statut `completed`.
- Notes de version françaises et anglaises : compatibilité, recherche du Coran, audio, Qibla et grands caractères.
- Le statut de piste confirme la soumission en production ; la disponibilité publique et l'état de l'examen Google n'ont pas été vérifiés dans la Console.

Les optimisations sont détaillées dans [l'audit de compatibilité](compatibility-audit-2026-09-09.md).
