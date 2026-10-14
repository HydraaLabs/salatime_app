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
