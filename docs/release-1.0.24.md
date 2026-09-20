# SalaTime Android 1.0.24 (27) — 20 septembre 2026

La notification de prière remonte lors de ses actualisations existantes sans
créer de doublon. Chaque prière activée conserve son adhan. Cette version active
aussi R8, améliore l'affichage bord à bord et réduit la mémoire nécessaire au
décodage des fonds d'écran.

## Publication vérifiée

- Source compilée : `45f4a40104650134b0db4e334101147133cf6db1`, poussée sur
  `HydraaLabs/salatime_app`, branche `main`. La compilation utilise un worktree
  isolé dont les fichiers suivis sont restés identiques au commit.
- Shorebird : release `842991`, version `1.0.24+27`, Android `active`.
  Le bundle distant a été téléchargé et son empreinte comparée au fichier local.
- Google Play : bundle `27` accepté, modification du canal `production` validée
  et enregistrée, puis relue par un nouvel edit. Version, empreinte, notes de
  version et conservation des autres canaux sont confirmées.
- À **22:06 UTC**, la Console affiche **1.0.24** sous « Modifications en cours
  d'examen », avec les **vérifications rapides en cours**. Elle indique que
  l'envoi pour examen suivra automatiquement. La publication gérée est désactivée.
  La version 1.0.23 précédemment en examen a été remplacée par cette soumission.

Le statut API `completed` correspond au déploiement complet demandé. Il ne
prouve pas la validation de Google ni la disponibilité publique. La nouvelle
version sera diffusée après validation. Il s'agit d'une nouvelle base Shorebird ;
les changements natifs nécessitent la mise à jour de l'application via Play.

## Bundle signé

| Propriété | Valeur |
| --- | --- |
| Application | `net.salatime.app` |
| Version | `1.0.24+27` |
| Taille AAB | 139 775 696 octets |
| SHA-256 | `68d22eb607f84fa52ebbba133a30048fda51a57621a3f5d431f1256317674841` |
| Flutter de production | Shorebird 3.41.6, `76ca3dff01cc7c5e6978e6b51e442777c6930419` |
| Android minimum / cible | 24 / 36 |
| Architectures | `arm64-v8a`, `armeabi-v7a`, `x86_64` |
| DEX décompressé | 4 434 704 octets, réduction de 80,72 % par rapport à 1.0.23 |

Commande de compilation :

```sh
shorebird release android --flutter-version 3.41.6 --no-confirm
```

Validation Bundletool, signature JAR, CRC, identifiants, version, absence du mode
debug, récepteurs privés et ressources vérifiés. Le certificat de signature est
identique à celui du bundle 1.0.23 envoyé à Play. Les 68 fichiers audio sont
conservés à l'identique dans les ressources Android et Flutter, ainsi que les
langues de l'interface, 1 141 fichiers de traduction coranique et le catalogue
des invocations. Les paramètres de production sont utilisés, sans option de
prévisualisation ni désactivation de la télémétrie.

Les métadonnées R8 incluses indiquent `noObfuscationPercentage=12.71`,
`noOptimizationPercentage=13.73` et `noShrinkingPercentage=12.89`. Le fichier de
correspondance des noms est inclus dans l'AAB et archivé séparément. Ce sont des
mesures de compilation ; le diagnostic de la Console Play doit encore être
actualisé. Les références aux anciennes API de couleur des barres restent
présentes dans le moteur Flutter, comme décrit dans le
[diagnostic des avertissements](play-warnings-2026-09-20.md).

## Vérifications

- Analyse Dart complète : aucun diagnostic, avec Shorebird Flutter 3.41.6.
- 629 tests Flutter réussis sur le commit publié, avec le même SDK Shorebird.
- 264 tests Android propres à SalaTime réussis, sans échec ni test ignoré, avec
  Flutter standard 3.41.8 et Robolectric 4.16. Ils couvrent notamment les
  notifications, les adhans successifs et le décodage des fonds d'écran.
- La dépendance Maven du moteur debug Shorebird 3.41.6 présente un décalage de
  version dans son descripteur ; les tests natifs utilisent donc le SDK standard.
  La compilation de production Shorebird a réussi séparément.
- Une exécution élargie aux tests internes des plugins a rencontré deux échecs
  dans l'ancien Robolectric de `flutter_local_notifications` 17.2.4 sous Java 21.
  Les suites SalaTime passent avec Robolectric 4.16. Les journaux des deux
  environnements et de cette limitation sont conservés.
- Les essais physiques précédents sur Samsung sont décrits dans le
  [compte rendu de la remontée des notifications](notification-recency-2026-09-20.md)
  et le diagnostic des avertissements. Le bundle final de production n'a pas
  remplacé l'installation Play du téléphone pendant cette publication.

Les travaux locaux sur les tablettes, leurs captures, la navigation et les
préférences de cloche sont conservés dans le checkout principal. Cette release
contient les corrections de notifications et d'avertissements Play sélectionnées
dans le commit source ci-dessus.

## Preuves locales

`release-artifacts/release-1.0.24/` contient le bundle signé, sa correspondance
R8, les journaux et résultats des tests, les empreintes, les réponses vérifiées
de Shorebird et Google Play, la copie de l'état visible de la Console, les
scripts de vérification et les sauvegardes des modifications antérieures.
Ces artefacts restent hors du dépôt Git.
