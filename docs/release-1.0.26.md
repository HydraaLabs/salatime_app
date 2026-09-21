# SalaTime 1.0.26 — décompte des prières

Le compteur du temps écoulé laisse place à la prochaine prière au plus tard
une heure après la précédente. La priorité existante est conservée lorsque la
prochaine prière est déjà à une heure ou moins. Le décompte devient rouge
strictement sous une heure et garde sa couleur normale à exactement 60 minutes.

Cette règle est commune aux accueils classique et moderne, aux widgets Android
et iOS et au compteur de notification Android. Les actualisations natives
suivent les nouveaux seuils. Le calcul des horaires et l'activation des adhans
ne sont pas modifiés.

## Publication Android vérifiée par API

La version **1.0.26 (30)** a été envoyée au canal `production` de Google Play le
21 septembre 2026. Le déploiement complet est demandé avec le statut API
`completed`. Ce statut ne prouve pas l'approbation ni la disponibilité publique.

- Source compilée et poussée : `e0fdc0e34db8b2377483d1fa4e00c4280b68473c`.
- Edit Play `03731490725376612286`, validé puis enregistré avec
  `changesInReviewBehavior=CANCEL_IN_REVIEW_AND_SUBMIT`.
- Un nouvel edit de lecture confirme le bundle 30, son empreinte et les notes
  françaises, anglaises et arabes. Les fiches, toutes leurs images (dont les
  30 captures tablette), leur ordre et les autres canaux sont conservés.
  L'edit de lecture a ensuite été supprimé sans publication.
- Shorebird : release `845357`, version `1.0.26+30`, Android `active`, artefact
  `3750942`. L'artefact distant téléchargé est identique à l'AAB envoyé à Play.
  Il s'agit d'une nouvelle release, pas d'un patch OTA des versions précédentes.
- La lecture de la Play Console confirme ensuite « Modifications en cours
  d'examen » pour la 1.0.26 et les six lots de captures tablette. La publication
  gérée est désactivée : la diffusion est automatique après validation.

Le [reçu Android](submission-android-1.0.26-30.json) conserve les identifiants et
les résultats de relecture, sans données d'authentification.

| Propriété | Valeur |
| --- | --- |
| Application | `net.salatime.app` |
| Taille AAB | 139 816 918 octets |
| SHA-256 AAB | `482774abde179da421dc0969e143684aba0ec53093cc7f0be4f4f832f75997d2` |
| SDK de production | Shorebird Flutter 3.41.6, `76ca3dff01cc7c5e6978e6b51e442777c6930419` |
| Android minimum / cible | 24 / 36 |
| Architectures | `arm64-v8a`, `armeabi-v7a`, `x86_64` |

Le worktree de compilation est resté identique au commit source. Bundletool,
signature JAR, CRC, versions, ressources et récepteurs privés ont été vérifiés.
Le certificat correspond à la release précédente. Les 68 sons et 1 141 fichiers
de traductions sont présents et identiques aux sources. L'optimisation R8 et
sa correspondance de noms sont archivées. Les copies temporaires des fichiers
de signature ont été retirées du worktree.

## Vérifications

- 638 tests Flutter réussis avec Flutter 3.41.8 et avec le SDK Shorebird de
  production 3.41.6 ; analyse sans anomalie avec les deux SDK.
- 42 tests Android ciblés réussis : 13 widgets et 29 notifications.
- Régressions sur les seuils stricts, le basculement automatique en thèmes
  clair/sombre, les prières rapprochées et le changement de jour.
- Compilation simulateur et suite native iOS `RunnerTests` réussies sur le
  serveur macOS avec Xcode 26.3 ; la suite comporte dix méthodes de test.

## Publication iOS

La version **1.0.26 (33)** est soumise à App Review depuis le 21 septembre 2026
à **19:13:41 UTC**. Le build est `VALID`, la version et la soumission sont
`WAITING_FOR_REVIEW`, avec publication automatique après approbation
(`AFTER_APPROVAL`). La [compilation signée](https://github.com/HydraaLabs/salatime_app/actions/runs/35638919005)
a réussi dès la première tentative avec le même commit source que l'AAB.

La relecture confirme les trois langues, les 36 captures iPhone/iPad, la vidéo
et les accès de revue conservés. Les connexions Apple/Google, les versions de
l'app et du widget et les 68 sons ont été vérifiés dans l'IPA récupéré. Apple
termine son traitement sans erreur ni avertissement. Voir le
[compte rendu iOS](app-store/release-1.0.26.md) et son reçu pour les identifiants
et empreintes.

Les deux stores ont reçu la nouvelle version. L'approbation et la disponibilité
publique ne sont pas encore confirmées.

## Preuves locales

Les artefacts Android restent hors Git dans `release-artifacts/release-1.0.26/` :
bundle signé, correspondance R8, journaux, résultats des tests et réponses
vérifiées de Shorebird et Google Play. Ces contrôles ne constituent pas un
nouvel essai sur un appareil physique.
