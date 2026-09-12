# Publication Android 1.0.15+18 — 12 septembre 2026

- Application : SalaTime (`net.salatime.app`).
- Sources : `f3ccf443b363a4307db61204f1edee57f97a0abc`, avec numéro porté à `1.0.15+18`.
- Choix indépendant des sons de l'adhan et des rappels avant/après dès la configuration initiale, avec préécoute et mémorisation.
- Rappels avant/après désactivés par défaut ; sélecteurs de son visibles uniquement pour les notifications activées. Les préférences déjà enregistrées sont conservées.
- Libellé français « Dohr » inclus et vérifié dans le bundle.

## Validation

- 80 tests Flutter réussis avec le SDK de publication ; analyse sans anomalie.
- SDK Shorebird Flutter `3.41.6`, révision `76ca3dff01cc7c5e6978e6b51e442777c6930419`.
- Construction : `shorebird release android --flutter-version 3.41.6 --build-name 1.0.15 --build-number 18 --no-confirm`.
- Manifeste vérifié : package `net.salatime.app`, version `1.0.15`, code `18`.
- Signature vérifiée avec `jarsigner` ; structure validée avec `bundletool validate`.
- AAB : 83 837 855 octets ; copie utilisée pour Play : `/tmp/SalaTime-1.0.15-18-shorebird.aab`.
- SHA-256 : `bbd974ed992b6f6a5aa52247df6315c3c4e3ab8b1c308b23aa9e98a88885f429`.

## Publications vérifiées par API

- Shorebird : application `53488219-9639-4aac-87fc-72812320f340`, release `826209`, Android `active`, artefact AAB `3663635` ; taille et empreinte conformes.
- Google Play : téléversement, validation et commit réussis sur la piste production. Relecture dans une nouvelle édition : release `1.0.15`, code `18`, statut `completed`.
- L'empreinte du bundle relu sur Google Play est identique à celle de Shorebird et du fichier local.
- Les pistes de test sont inchangées, vérifiées avant et après publication.
- La disponibilité publique et l'état de l'examen Google ne sont pas confirmés par cette relecture API de la piste production.
