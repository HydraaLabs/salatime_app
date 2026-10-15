# SalaTime 1.0.33 — recherche des mosquées fiable

Android : `1.0.33+43`. iOS : `1.0.33 (43)`.

## Contenu

- **Mosquées proches** : l'app interroge d'abord le relais
  `https://salatime.net/api/mosques/nearby` (cache OpenStreetMap par zone de
  ~2 km, frais 7 jours, servi jusqu'à 60 jours en cas de panne ; dépôt
  HydraaLabs/salatime `8d83af2`, en production depuis le 15 octobre 2026),
  puis OpenStreetMap directement, puis les derniers résultats enregistrés
  pour la même zone ; sinon un message clair. Noms dans la langue de l'app.
- Aucune nouvelle autorisation ni collecte de données.

## Notes de version

- fr : Recherche des mosquées proches plus fiable : résultats plus rapides,
  conservés quand le service de cartes est saturé, et noms dans votre langue.
- en : More reliable nearby mosque search: faster results, kept when the map
  service is busy, and mosque names in your language.
- ar : بحث أكثر موثوقية عن المساجد القريبة: نتائج أسرع، تبقى متاحة عند انشغال
  خدمة الخرائط، وأسماء المساجد بلغتك.

## Publication

- Base vérifiée le 15 octobre 2026 : 1.0.32 (42) publiée sur Google Play ;
  App Store : 1.0.32 en attente de revue, 1.0.31 en vente.
- iOS : build 43 envoyé sans soumission ; 1.0.33 soumise en mode reprise
  après l'approbation de la 1.0.32.
