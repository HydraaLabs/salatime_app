# SalaTime 1.0.25 (29) — tablettes Android et intégration iOS

Publication Android du 21 septembre 2026. La navigation s'adapte aux tablettes
et aux fenêtres redimensionnées ; l'accueil utilise deux colonnes lorsque la
largeur le permet. La cloche d'une prière commande aussi ses rappels avant et
après l'adhan. Le son par défaut de l'iqama du vendredi est corrigé, y compris
pour l'ancienne valeur enregistrée. Ces changements partagés s'appliquent aussi
à iOS. Les adhans des prières actives restent pris en charge.

## Publication Android vérifiée par API

- Source compilée et poussée : `035ac84bca57919ba929edfb210fb0358578399d`,
  branche `main` de `HydraaLabs/salatime_app`.
- Google Play : bundle `29`, version `1.0.25`, canal `production`, déploiement
  complet demandé avec le statut API `completed`.
- Edit `00511229986337321850` validé puis enregistré avec
  `changesInReviewBehavior=CANCEL_IN_REVIEW_AND_SUBMIT`. La soumission remplace
  la précédente version 1.0.24 sur le canal production.
- Un nouvel edit de lecture confirme la version, l'empreinte du bundle, les
  notes de version, les 30 images et leur ordre. Les textes des fiches, leurs
  autres images et les autres canaux sont conservés. L'edit de lecture a ensuite
  été supprimé sans publication.
- Shorebird : release `843068`, Android `active`, version `1.0.25+29`, artefact
  `3740853`. Le bundle distant téléchargé est identique au bundle envoyé à Play.
- La Console Google Play confirme ensuite « Modifications en cours d'examen »
  pour 1.0.25 et les six lots de captures tablette. La publication gérée est
  désactivée : la diffusion est automatique après validation.

La disponibilité publique reste soumise au traitement et à la validation de
Google. Le statut API `completed` ne prouve pas cette validation. L'envoi du
bundle, des images et la publication utilisent l'API. L'interface de la Console
a uniquement été consultée ensuite pour confirmer l'entrée en examen.

Le build intermédiaire `1.0.25+28` a servi à découvrir un défaut de contraste de
l'heure au-dessus de la navigation latérale. Il n'a pas été envoyé à Play. Le
build 29 réserve une même surface de barre d'état au-dessus des deux panneaux.

## Captures tablette

| Langue | Format 7 pouces | Format 10 pouces |
| --- | --- | --- |
| Français (`fr-FR`) | 5 images, 1080 × 1920 | 5 images, 1440 × 2560 |
| Anglais (`en-US`) | 5 images, 1080 × 1920 | 5 images, 1440 × 2560 |
| Arabe (`ar`) | 5 images, 1080 × 1920 | 5 images, 1440 × 2560 |

Les décors et textes des visuels mobiles sont conservés ; de vrais écrans de
l'application sur émulateur tablette remplacent l'interface mobile sans
étirement ni génération par IA. Les 30 empreintes SHA-256 ont été comparées aux
réponses de Google après l'enregistrement. La provenance, les exclusions et les
profils de capture sont décrits dans [Android tablets](android-tablets.md).

## Bundle signé

| Propriété | Valeur |
| --- | --- |
| Application | `net.salatime.app` |
| Version | `1.0.25+29` |
| Taille AAB | 139 817 026 octets |
| SHA-256 | `cf72b32dec545a05df654eaf63b224b750f8e62ce1a4981a3592fb311a5433c1` |
| SDK de production | Shorebird Flutter 3.41.6, `76ca3dff01cc7c5e6978e6b51e442777c6930419` |
| Android minimum / cible | 24 / 36 |
| Architectures | `arm64-v8a`, `armeabi-v7a`, `x86_64` |

Le worktree de compilation est resté identique au commit source. Bundletool,
signature JAR, CRC, ressources, récepteurs privés et absence du mode debug ont
été vérifiés. Le certificat de signature correspond au bundle Play précédent.
Les 68 sons, 1 141 fichiers de traductions et le catalogue des invocations sont
présents. R8 conserve ses optimisations et sa correspondance de noms archivée.
Les ressources natives Android de notifications ne changent pas depuis 1.0.24.

## Vérifications et portée iOS

- Analyse complète avec le SDK de production : aucun diagnostic.
- 636 tests Flutter réussis sur l'intégration `558598d` avec le SDK Shorebird ;
  après l'ajustement de la barre d'état, les 19 tests de navigation et d'insets
  repassent localement sur `035ac84`, puis les 636 tests passent sur macOS avec
  Flutter 3.41.8.
- L'APK dérivé du bundle final a été installé sur un émulateur Android 15/API 35.
  Les contrôles visuels couvrent 1200 × 1920, 780 × 1688 et 2560 × 1600 à 320 dpi :
  navigation, maintien de l'écran ouvert lors du redimensionnement, contraste de
  l'heure et accueil en deux colonnes. Aucun crash ni débordement Flutter observé
  dans les journaux du processus. L'APK de test utilise une signature debug ;
  l'AAB Play conserve sa signature d'envoi. Pas de nouvel essai physique Samsung.
- La première vérification iOS
  [35545011325](https://github.com/HydraaLabs/salatime_app/actions/runs/35545011325)
  réussit : compilation simulateur et WidgetKit, analyse, 636 tests Flutter,
  compilation iPhone sans signature et neuf tests natifs, dont la présence et la
  durée des 68 sons. Le lancement est capturé sur simulateurs iPhone et iPad.
  L'arbre Git `ios/` est identique sur les commits `558598d` et `035ac84` :
  `266ca56eeb5964f11580b95f1ac7a0e31bc6fc2a`.
- La vérification du commit final est suivie dans
  [35546091438](https://github.com/HydraaLabs/salatime_app/actions/runs/35546091438).
  Sa première tentative compile les deux variantes iOS et passe les 636 tests
  Flutter, puis le moteur XCTest dépasse son délai avant le démarrage des
  tests natifs (`The test runner timed out while preparing to run tests`).
  La vérification est relancée sur un nouveau serveur, avec le même commit.

Les modifications iOS sont intégrées au dépôt. Cette opération ne soumet pas de
nouveau build à App Store Connect et ne constitue pas un essai sur iPhone
physique. Le comportement partagé et la migration du son sont détaillés dans
[Shared iOS and tablet changes](shared-ios-tablet-changes.md).

## Preuves locales

`release-artifacts/release-1.0.25/` contient le bundle signé, la correspondance
R8, les journaux et résultats des tests, les captures de contrôle, la provenance
des images et les réponses vérifiées de Shorebird et Google Play. Les artefacts
restent hors de Git ; les copies temporaires des secrets de signature du
worktree de compilation ont été retirées.
