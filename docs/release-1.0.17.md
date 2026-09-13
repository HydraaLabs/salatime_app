# SalaTime Android 1.0.17+20

Application de production : `net.salatime.app`.

## Contenu

- Adhan respectant le mode silencieux/vibreur avant et pendant la lecture.
  Arrêt avec les boutons de volume et les transitions de veille/réveil ;
  bouton Arrêter de la notification conservé. En arrière-plan, l'arrêt par
  volume nécessite un changement effectif de valeur. Les détails Android et
  la limite aux volumes extrêmes sont dans `adhan-silent-and-side-buttons.md`.
- Athkar cochés et progression de lecture du Coran enregistrés localement,
  avec historique et statistiques. Synchronisation sur le compte SalaTime
  une minute après le dernier changement, reprise hors ligne et isolation
  des données par compte. Les lectures ne sont pas cochées à l'ouverture.
- Traductions publiées du Coran dans les dix langues de l'application, suivies
  automatiquement et disponibles hors ligne. Sources QuranEnc, traducteurs,
  versions et notes conservés ; français Muhammad Hamidullah. L'arabe utilise
  le tafsir Al-Muyassar. Aucun texte coranique réécrit ou traduit manuellement.
- Invitation neutre à donner un avis Google Play après sept jours et trois
  jours d'utilisation. Report de trente jours, refus définitif et arrêt des
  relances après ouverture de la fiche. Aucun filtrage selon la satisfaction.
- Navigation des sourates adaptée aux petits écrans et aux libellés longs ;
  source de traduction et diagnostic des alarmes clarifiés.

## Préparation

Le code de version 20 est libre dans l'API Google Play ; la dernière version
Shorebird Android relue avant publication est 1.0.16+19 (release 826646).
La compilation utilise le SDK Shorebird Flutter 3.41.6 déjà validé sur la
version précédente, avec les architectures ARM32, ARM64 et x86_64.

Les nouvelles commandes d'arrêt de l'adhan sont natives Android. Elles
nécessitent un nouvel APK/AAB et ne sont pas distribuables par un patch Dart.
Le Samsung n'est pas connecté lors de cette publication ; la vérification
physique du dernier correctif n'est pas revendiquée.

## Validation avant publication

- 491 tests Flutter passent avec le SDK épinglé 3.41.6 ; analyse globale sans
  anomalie et `git diff --check` propre.
- 152 tests Android natifs passent, dont les régressions silencieux/vibreur,
  boutons latéraux et cycle de vie du lecteur.
- Vérification hors ligne des 10 éditions QuranEnc : 114 sourates et 6 236
  versets par édition, empreintes identiques au manifeste.
- API des lectures : 43 tests et 627 assertions côté Laravel ; code du
  serveur relu et identique au commit web publié
  `f5b875a7a33d037bef4a4a027db20558c9a5eead`.

Les reçus des canaux de publication seront ajoutés après leurs contrôles.
