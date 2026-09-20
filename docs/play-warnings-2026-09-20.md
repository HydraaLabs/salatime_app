# Avertissements Google Play — vérification du 20 septembre 2026

La version Android 1.0.23 signalait une obfuscation DEX de 1 %, deux
recommandations sur l'affichage bord à bord et un décodage de fond d'écran
sans sous-échantillonnage. Ce document décrit la validation des corrections
avant leur [soumission avec la version 1.0.24](release-1.0.24.md).

## Corrections

- Activation de R8 et de la réduction des ressources pour les builds release.
  Les modèles persistés par `flutter_local_notifications`, leurs noms de champs,
  leurs sous-types et les signatures génériques Gson restent protégés pour
  conserver la compatibilité des notifications enregistrées avant la mise à jour.
  Les sons chargés par leur nom et l'icône de notification sont conservés.
- Activation explicite du mode bord à bord dans Android et Flutter. Le fond
  derrière les barres système est peint par Flutter, les icônes suivent le thème
  de SalaTime et les contrôles restent à l'intérieur des zones sûres. Android
  conserve sa protection de contraste pour la navigation à trois boutons.
- Copie locale du module MIT `wallpaper_setter` 1.0.1, avec son interface Dart et
  son code iOS inchangés. Le décodeur Android lit les dimensions avant les pixels,
  choisit `inSampleSize` selon la destination et limite le résultat à 4 194 304
  pixels (16 Mio en ARGB8888). Le bitmap est libéré après sa copie par Android.
- Extension de l'option existante `salatimePreview` aux builds release : une
  installation `.preview`, signée avec la clé de développement, permet de tester
  le code optimisé à côté de l'application Play sans remplacer ses données.

## Mesures sur les artefacts

| Mesure | Bundle envoyé précédemment à Play | Bundle de validation |
| --- | ---: | ---: |
| Taille DEX décompressée | 23 001 968 octets | 4 434 148 octets |
| Nombre de fichiers DEX | 5 | 1 |
| Métadonnées R8 et correspondance des noms | absentes | incluses |
| Sons MP3 Android | 68 | 68, contenus identiques |

La taille DEX diminue de **80,72 %**. Les métadonnées `r8.json` du bundle indiquent
`noObfuscationPercentage=12.71`, `noOptimizationPercentage=13.73` et
`noShrinkingPercentage=12.89`, soit des indicateurs d'obfuscation, d'optimisation
et de réduction de 87,29 %, 86,27 % et 87,11 % selon ces mesures R8.
Ces mesures locales ne constituent pas un nouveau résultat publié par Play.

Google décrit l'utilisation de ces métadonnées et le seuil de taille DEX
dans sa [documentation sur l'optimisation DEX](https://developer.android.com/topic/performance/vitals/code-optimization).

## Vérifications

- 631 tests Flutter et 262 tests Android natifs réussis ; analyse des fichiers
  Dart modifiés sans diagnostic. Les cinq tests de mise en page ont également
  été rejoués après l'ajustement final du contraste.
- Couverture des marges avec navigation par gestes et à trois boutons, découpe
  latérale en paysage, ouverture du clavier et changement de thème.
- Décodage réel d'une image réduite, dimensions extrêmes, plafond de pixels,
  fichier absent et image invalide vérifiés avec Robolectric.
- Compilation d'un AAB release et d'un APK release `.preview` avec R8 actif,
  Flutter 3.41.8, AGP 8.11.1 et R8 8.11.18.
- Sur émulateur Android 15, des notifications sérialisées par l'ancien bundle
  ont été relues puis réécrites par le code minifié après mise à jour : cinq
  sous-types, identifiants, charges utiles, sons, énumérations et liste typée
  Gson conservés. Démarrage à froid de l'application réussi.
- Sur Samsung SM-S901U / Android 12, installation séparée, ouverture et parcours
  des réglages vérifiés. Le premier test d'alarme a été livré avec 201 ms de
  décalage ; les journaux montrent 32 secondes de lecture, puis un arrêt à
  l'appui sur Marche. L'utilisateur n'entendait pas le son au volume Alarme 1/15.
  Au second essai, à 8/15 (53 %), l'utilisateur a confirmé entendre l'adhan,
  après déclenchement écran éteint. La livraison a été enregistrée 412 ms
  après l'heure prévue. Le niveau du canal Alarme et le maintien de l'écran
  allumé pendant les manipulations sont restaurés à leurs valeurs initiales ;
  les deux installations de test sont retirées. L'installation Play 1.0.22+25
  du téléphone n'a pas été remplacée.

## Limite du diagnostic Flutter

Les appels `Window.setStatusBarColor`, `setNavigationBarColor` et
`setNavigationBarDividerColor` restent présents dans le moteur Flutter 3.41.x
embarqué. Les réglages directs de ces couleurs ont été retirés du code de
SalaTime, mais l'analyse statique de Play peut encore signaler le moteur.
Le problème est décrit dans le
[suivi Flutter des avertissements Android 15](https://github.com/flutter/flutter/issues/183372).
La disparition des cartes de recommandation devra être vérifiée après l'analyse
par Google d'une prochaine publication.

## Conservation des preuves

Les journaux, métadonnées R8, correspondances de noms, empreintes et captures
sont conservés localement dans `release-artifacts/play-warnings-2026-09-20/`.
Le bundle de validation désactive la télémétrie et utilise Flutter standard ;
il sert à la vérification et ne remplace pas la procédure de release Shorebird.
Son SHA-256 est
`14efac73fdd57d52115620e3bb869d3bc46a9b049e271adcdf42e7820cbd6d99`.

La phase de validation décrite ici n'a pas effectué de publication. Le push,
la release Shorebird et la soumission Play ultérieurs sont consignés dans le
[compte rendu de la version 1.0.24](release-1.0.24.md). Les autres modifications
locales présentes avant l'intervention sont conservées.
