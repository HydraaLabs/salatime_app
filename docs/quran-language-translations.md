# Traduction du Coran selon la langue de l'application

Modification du 13 septembre 2026, postérieure aux artefacts Play/Shorebird
1.0.16+19. Les travaux de suivi des lectures déjà présents sont conservés.

## Origine et affichage

Le lecteur choisissait auparavant l'ID de traducteur historique `1` (anglais),
indépendamment de la langue de l'interface. Les lecteurs en ligne et hors ligne,
la recherche et le verset quotidien utilisent maintenant une même édition
publiée correspondant à la langue de l'application.

Les dix langues proposées disposent d'un corpus complet de 114 sourates et
6 236 entrées chacune. Le français utilise Muhammad Hamidullah, édition
`french_hameedullah` 1.0.2 publiée par QuranEnc sous supervision Rowwad. L'arabe
utilise le commentaire At-Tafsir Al-Muyassar du Complexe du roi Fahd ; il est
identifié comme un tafsir. Le tableau complet des éditions et versions est dans
`assets/quran/translations/manifest.json`.

Aucun texte de verset ou de note n'a été traduit, corrigé ou reformulé par
SalaTime. Les 62 360 couples texte/notes ont été comparés exactement aux exports
SQLite officiels. Le balisage de présentation présent dans les notes est rendu
en texte lisible : gras et sauts de ligne. Les données sources restent intactes.
Les notes peuvent être dépliées dans le lecteur, et le partage inclut les notes,
l'édition, l'éditeur, la version et le lien de la source.

Le réglage de traduction indique désormais sa source et son lien avec la langue
de l'application. L'ancien choix numérique sauvegardé ou restauré du cloud ne
peut plus réimposer l'anglais au lecteur français. La langue existante reste la
préférence synchronisée ; aucun nouveau champ de compte ni changement d'API
mobile n'est nécessaire pour choisir ces éditions.

## Fiabilité et ressources

- Les traductions sont embarquées et lisibles sans requête réseau, y compris
  pour le lecteur utilisé lorsque le téléphone est connecté.
- Fichiers séparés par langue et sourate ; cache limité à huit chapitres,
  parsing hors de l'isolate d'interface, requêtes locales concurrentes partagées.
  Les modèles d'affichage restent indépendants pour éviter une contamination
  entre traductions. Le plus gros chapitre fait environ 1,26 Mo.
- Changer la langue conserve la sourate ouverte, vide les anciennes données et
  ignore les chargements devenus obsolètes. L'index de recherche est renouvelé
  seulement s'il avait été demandé ; aucune note volumineuse n'est indexée.
- Une édition manquante ou invalide affiche une erreur et une possibilité de
  réessayer, sans remplacer silencieusement le texte par une autre langue.
- Le texte arabe, les numéros canoniques et les cases de lecture sont conservés.
  Le verset quotidien garde la même référence dans toutes les langues.
- Les boutons de navigation restent adaptés aux grands textes. Le nombre total
  de versets dans l'en-tête est localisé et distinct des versets cochés comme lus.

## Sources et actualisation

- Documentation et conditions : https://quranenc.com/en/home/api/
- Édition française : https://quranenc.com/en/browse/french_hameedullah
- Métadonnées, conditions de réutilisation et reproduction :
  `assets/quran/translations/README.md`.
- Contrôle local des empreintes et de la couverture :
  `python3 tools/import_quranenc_translations.py --verify-only`.
- Toute actualisation des éditions nécessite une nouvelle vérification des
  versions et des sources avec l'importeur. Les fichiers de provenance sont
  conservés et les auteurs sont crédités dans l'interface.

Les nouveaux fichiers embarqués nécessitent un futur build complet pour une
publication mobile ; ils ne sont pas fournis par un simple patch Dart Shorebird.

## Vérification

- Analyse Flutter globale sans anomalie avec le SDK de publication 3.41.6.
- 459 tests Flutter réussis, incluant le suivi de lecture et les autres fonctions
  existantes. Les cas nouveaux couvrent les dix éditions, les notes et sources
  intactes, le cache, la reprise après erreur, les changements de langue, les
  réponses tardives, le verset quotidien et les 6 236 versets de l'index français.
- Les deux lecteurs réels ont été rendus avec Al-Fatiha de Hamidullah et leurs
  cases de lecture. Captures d'interface vérifiées à 320 px, ainsi que les
  réglages français/arabe en clair/sombre avec texte agrandi à deux fois.
- Le contrôle indépendant des 1 140 fichiers confirme leurs empreintes et
  exactement 6 236 textes/notes par édition ; la comparaison avec les SQLite
  officiels confirme l'absence de réécriture.

## Prévisualisation

- APK `SalaTime-test-traductions-officielles-1.0.16-19.apk`, construit avec Flutter
  3.41.8 ; 201 634 262 octets ; SHA-256
  `caa8aca62ac692efd1cf0f9763590e1711ca037e69007dbbd468e34b3e779242`.
- Le manifeste et les 1 140 chapitres dans l'APK correspondent exactement aux
  fichiers validés. Package `net.salatime.app.preview`, libellé SalaTime Test,
  signature debug vérifiée. Version de travail 1.0.16+19, distincte par son
  empreinte des artefacts de production et des prévisualisations précédentes.
- Installée sur le Samsung SM-S901U avec conservation des données ; empreinte
  de l'APK installé relue et identique. Le téléphone reste verrouillé : les
  captures et vérifications visuelles citées ci-dessus proviennent des tests
  Flutter, pas d'un contrôle des nouveaux écrans sur ce téléphone.
- Aucun nouveau dépôt distant, site, APK public, Play Store ou Shorebird publié
  dans le cadre de cette modification.
