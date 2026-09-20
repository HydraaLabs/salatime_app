# SalaTime Android 1.0.23+26

Correctif des changements d'heure, notamment au Maroc, publié à la demande
du propriétaire le 20 septembre 2026. Package : `net.salatime.app`.

## Source

Le bundle provient de la branche `release/android-1.0.23`, commit
[`714433c`](https://github.com/HydraaLabs/salatime_app/commit/714433cf4faa8e1e6d0be5de30217f8ed5da9d2f).
Le code est identique au patch Shorebird `c09f884` de 1.0.22+25 ; seul le numéro
de version passe à 1.0.23+26. La construction utilise un checkout isolé, avec
Shorebird Flutter 3.41.6, révision `76ca3dff01cc7c5e6978e6b51e442777c6930419`.

Le correctif actualise les règles de fuseaux et utilise les règles locales du
téléphone pour sa zone. Il recalcule les horaires, les widgets et les rappels
lors des changements d'heure ou de fuseau. Voir [timezones.md](timezones.md)
et [la publication du patch](shorebird-timezone-2026-09-20.md).

## Validation

Les **599 tests Flutter** et l'analyse sans problème du patch précédent
portent sur ce même code et ce même SDK. La nouvelle compilation de production
est réussie. `bundletool validate`, la signature du bundle, le package, la
version et les receivers privés sont vérifiés. Le certificat correspond à
celui du bundle code 25 déjà accepté par Google Play.

Le bundle contient les trois architectures Android, les **68 sons** et les
**1 141 fichiers de traduction du Coran** vérifiés contre les sources.
Android minimum : API 24 ; cible : API 36. Aucun nouvel essai sur appareil
physique n'a été effectué pour cette publication.

Bundle : **143 289 771 octets**, SHA-256
`f6cec47ad35ac1afa82f2f03b2f1aa96262feb804358736ee334a592d6dbee55`.
Les reçus, la provenance et les journaux sont conservés localement dans
`release-artifacts/play-timezone-2026-09-20/`.

## Shorebird

La release **842906**, version **1.0.23+26**, est active pour Android.
L'artefact **3740130**, téléchargé intégralement après publication, possède
la même taille et le même SHA-256 que le bundle signé local.
Cette nouvelle base conserve la possibilité de recevoir des correctifs
Shorebird. Le patch 1 de 1.0.22+25 reste destiné aux installations de la
version précédente.

## Google Play

Le bundle a été téléversé, puis l'édition de production validée et commitée.
Une nouvelle édition de lecture confirme **1.0.23/code 26**, statut API
`completed`, avec le même SHA-256. Les pistes beta, alpha et internal sont
inchangées ; l'édition de vérification a été supprimée avec HTTP 204.

La Console confirme **1.0.23** dans « Modifications en cours d'examen », pour
un déploiement complet. À la vérification, les contrôles rapides automatiques
sont encore en cours et Google indique un envoi pour examen à leur issue.
La publication gérée reste désactivée. L'approbation et la disponibilité
publique de cette nouvelle version ne sont pas encore confirmées.

Reçu : `salatime-play-1.0.23-publication.json`, phase `verified` ; capture
textuelle : `salatime-1.0.23-console-after.txt`, dans le dossier local de reçus.
La copie principale du dépôt reprend le numéro 1.0.23+26 pour les prochaines
constructions ; la source exacte du bundle publié reste le commit isolé
`714433c` cité ci-dessus.
