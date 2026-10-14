# SalaTime 1.0.31 — compteur des widgets, démarrage et dépendances

Android : `1.0.31+41`. iOS : `1.0.31 (41)`.

## Contenu

- **Widgets** : le compte à rebours affiche la prochaine prière avec
  « dans » et `HH:mm:ss` (par exemple « Assr dans 00:44:09 ») sur Android et
  iOS, traduit en français, anglais et arabe. Correctif préparé et validé le
  10 octobre, appliqué sans modification (14 fichiers conformes aux empreintes
  de `release-scope.json`).
- **Démarrage** : seules la langue active et l'anglais de repli sont lus avant
  le premier écran ; les autres langues sont chargées à la sélection
  ([détails](startup-translations-and-assets-2026-10-14.md)).
- **Taille** : retrait de fichiers jamais lus (`assets/quran/ar`, `bn`, `sp`,
  21 fichiers de langue sans entrée dans l'app) : AAB signé −3,5 Mo.
- **Dépendances** : AGP 8.12.3, `share_plus` 13, `package_info_plus` 10,
  `flutter_secure_storage` 11, `geolocator` 14, `flutter_qiblah` 3.2,
  `flutter_timezone` 5 et 41 mises à jour mineures
  ([détails et paquets écartés](dependency-updates-2026-10-14.md)).

Aucune nouvelle autorisation ni collecte de données. Les changements natifs
imposent une publication complète : ils ne peuvent pas être livrés par un
patch Shorebird sur la 1.0.30.

## Notes de version

- fr : Widgets : le compte à rebours affiche la prochaine prière en heures,
  minutes et secondes (par exemple « Assr dans 00:44:09 »). Démarrage plus
  rapide et application plus légère. Mises à jour techniques de la
  localisation, de la Qibla et du partage.
- en : Widgets: the countdown shows the next prayer in hours, minutes and
  seconds (for example “Asr in 00:44:09”). Faster startup and a smaller app.
  Technical updates to location, Qibla and sharing.
- ar : الأدوات: يعرض العدّ التنازلي الصلاة القادمة بالساعات والدقائق والثواني
  (مثل «العصر بعد 00:44:09»). تشغيل أسرع وحجم أصغر للتطبيق. تحديثات تقنية
  لتحديد الموقع والقبلة والمشاركة.

## Vérification avant publication

- Base : la 1.0.30 (40) est publiée sur Google Play (`PUBLISHED`) et sur
  l'App Store (`READY_FOR_SALE`), relu le 14 octobre 2026.
- Les résultats de tests, de builds et de publication sont consignés dans
  `release-artifacts/release-1.0.31/` (local).

## Publication du 14 octobre 2026

- Source : `a5780b54502f2c813d9dc1a0a3a6dcee041ba398` (`release/1.0.31`).
  La vérification iOS a d'abord échoué sur une erreur de compilation du test
  Swift ajouté par le correctif widget (littéral `[Any]`), corrigée par
  `a5780b5` ; le code de l'app n'était pas concerné.
- Tests : 828 Flutter (aussi avec Flutter 3.41.6 de Shorebird), 272 natifs
  Android dont 16 du widget ; [vérification iOS](https://github.com/HydraaLabs/salatime_app/actions/runs/38610615224)
  réussie (builds, tests natifs, lancements iPhone et iPad).
- Shorebird : release `1.0.31+41` publiée avec Flutter 3.41.6 ; binaires
  natifs distants identiques à l'AAB vérifié.
- AAB : 137 392 437 octets, SHA-256
  `350f5e129e73d99a87b835722072414ce1b4b5c94c6342008e8f48c9abaa6f91`, même
  certificat d'upload que la 1.0.30, trois ABI, R8.
- Google Play : version `1.0.31 (41)` envoyée en production, état
  `IN_REVIEW` ; autres tracks, dix fiches, images et détails conservés.
- APK : 157 769 763 octets, SHA-256
  `6834c21be300f87af614b7399d66b3483f55ea49c6992806a07fe439ed5184f8`, relu
  sur les trois liens publics ; sauvegarde de l'APK 1.0.30 conservée sur le
  serveur. [APK versionné](https://salatime.net/dl/SalaTime-1.0.31-41.apk).
- iOS : [run de distribution](https://github.com/HydraaLabs/salatime_app/actions/runs/38614793622)
  réussi ; build `41` `VALID`, version `1.0.31` `WAITING_FOR_REVIEW` avec
  publication automatique après approbation, confirmé par une lecture Apple
  indépendante.

La disponibilité publique dépend des revues Google et Apple.
