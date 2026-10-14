# SalaTime 1.0.32 — recherche, accueil et widget

Android : `1.0.32+42`. iOS : `1.0.32 (42)`.

## Contenu

- **Recherche** des sourates (Coran en ligne, hors ligne et audio) et des
  récitateurs, par nom arabe, traduit ou translittéré et par numéro.
  Fonctionnalité de la branche `test/iphone-reading-search-20260929`, jamais
  publiée jusqu'ici.
- **Progression de lecture** : invitation à se connecter pour sauvegarder la
  lecture dans le compte.
- **Accueil moderne** : bouton « Aujourd'hui » quand un autre jour est
  affiché ; ligne « Milieu de la nuit » après l'Eshâ, dont la cloche est le
  rappel *Autres notifications → Milieu de la nuit* (désactivé par défaut).
- **Widget** : date de l'hégire, avec la correction de calendrier de
  l'utilisateur, sur la ligne de date (Android et iOS) ; le mot « dans » du
  compte à rebours est aussi transmis lors de la programmation des alarmes.
- **Compte** : boutons Google et Apple aux couleurs et logos officiels.
- **Statistiques** : quatre actions sans paramètre (`surah_search`,
  `reciter_search`, `reading_cloud_prompt`, `prayer_day_today`) ; aucun texte
  saisi ni choix n'est transmis.

Aucune nouvelle autorisation. Les changements natifs (widgets) imposent une
publication complète, pas un patch Shorebird.

## Notes de version

- fr : Recherche des sourates et des récitateurs en arabe, en français ou en
  translittération. Accueil : bouton « Aujourd’hui » et horaire du milieu de la
  nuit avec rappel activable. Date de l’hégire dans le widget. Nouveaux
  boutons de connexion Google et Apple.
- en : Search surahs and reciters in Arabic, English or transliteration. Home:
  a Today button and the middle of the night time with an optional reminder.
  Hijri date in the widget. Refreshed Google and Apple sign-in buttons.
- ar : البحث عن السور والقراء بالعربية أو بالحروف اللاتينية. الصفحة الرئيسية:
  زر «اليوم» ووقت منتصف الليل مع تذكير اختياري. التاريخ الهجري في الأداة.
  أزرار جديدة لتسجيل الدخول عبر Google وApple.

## Publication

- Base vérifiée le 14 octobre 2026 : 1.0.31 (41) publiée sur Google Play ;
  sur l'App Store, 1.0.31 encore en attente de revue.
- iOS : le build 42 est envoyé à App Store Connect sans soumission ; la
  version 1.0.32 est soumise (mode reprise du workflow) après l'approbation
  de la 1.0.31.
- Reçus : `release-artifacts/release-1.0.32/` (local).
