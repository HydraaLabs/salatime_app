# Publication Android 1.0.12+15 — 12 septembre 2026

- Application : SalaTime (`net.salatime.app`).
- Sources : commit `a730f75825e96ca0fe9f2e18b66c1699067b4167`, avec version portée à `1.0.12+15`.
- Widget Android compact avec la même mosquée en fond que l'accueil, présentation adaptée à la taille, cinq horaires dans le format agrandi, prise en charge du français, de l'arabe et du format 12/24 h.
- Catégories en grille de trois colonnes par défaut, avec mémorisation du choix de présentation.
- Ouverture directe des itinéraires vers les mosquées, avec repli vers le navigateur intégré si l'application externe ne s'ouvre pas.
- Calcul des horaires hors ligne, programmation des rappels sur plusieurs jours et restauration des alarmes après redémarrage Android ; carte Qibla et écran des prochaines alarmes.
- Version Android complète requise pour les nouveaux composants natifs. Aucun patch n'est appliqué aux anciennes versions et aucune publication iOS n'est effectuée.

## Validation

- Flutter Shorebird `3.41.6`, révision `76ca3dff01cc7c5e6978e6b51e442777c6930419`.
- Analyse Flutter sans anomalie ; 75 tests Flutter réussis.
- `:app:testReleaseUnitTest` : 12 tests Android réussis (restauration des alarmes, badges, widget).
- Construction : `shorebird release android --flutter-version 3.41.6 --build-name 1.0.12 --build-number 15 --no-confirm`.
- Manifeste du bundle vérifié : `net.salatime.app`, version `1.0.12`, code `15`, SDK minimum `24`, cible `36` ; les receivers du widget et de restauration sont présents.
- Signature vérifiée avec `jarsigner`, structure validée avec `bundletool validate`.
- AAB : `build/app/outputs/bundle/release/app-release.aab`, 83 797 866 octets.
- SHA-256 : `758c7fcea18b53f64fb2529773eddd9b23fa995ad5868098f1482b1d2ea3793c`.
- Les tests automatisés ne constituent pas une validation sur le téléphone de l'utilisateur.

## Shorebird

- Application : `53488219-9639-4aac-87fc-72812320f340` ; release : `825616`.
- Relecture API : version `1.0.12+15`, plateforme Android `active`.
- Artefact distant `3660926` : taille et SHA-256 identiques au bundle local.

## Google Play

- Téléversement du même AAB, contrôle SHA-256, validation puis commit de la piste production par Android Publisher API.
- Notes de version en français et en anglais ; autres pistes préservées.
- Relecture dans une nouvelle édition : release `1.0.12`, `versionCodes: ["15"]`, statut `completed`, SHA-256 identique.
- Vérification dans la Console : `1.0.12` apparaît sous « Modifications en cours d'examen », action « Lancer le déploiement complet ». Les vérifications rapides sont en cours ; leur fin déclenche automatiquement l'examen Google.
- La publication gérée est désactivée : la diffusion est automatique après approbation. La disponibilité publique de `1.0.12` n'est pas encore confirmée ; la Console affiche le 8 septembre 2026 comme dernière publication.
