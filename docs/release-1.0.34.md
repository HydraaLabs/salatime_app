# SalaTime 1.0.34 — fiches App Store et langues

iOS uniquement : `1.0.34 (44)`. Android reste en `1.0.33+43` (aucun changement
fonctionnel ; les fiches Google Play ont été corrigées par l'API le 18 octobre 2026).

## Contenu

- `CFBundleLocalizations` déclare les 10 langues de l'app (l'App Store
  n'affichait qu'« English »).
- Nouveaux mots-clés App Store en anglais, français et arabe (100 octets,
  sans répéter le nom ni le sous-titre).
- Nouvelles fiches App Store en turc, indonésien, malais et espagnol
  (Espagne et Mexique) : nom, sous-titre, description, mots-clés, texte
  promotionnel et notes (`tool/ios_store_locales.py`). Captures : celles de
  la langue principale.
- Aucune nouvelle autorisation ni collecte de données.

## Notes de version

Voir `WHATS_NEW` (fr, en, ar) et `NEW_LOCALE_WHATS_NEW` (tr, id, ms, es).

## Publication

- Base vérifiée le 18 octobre 2026 : 1.0.33 (43) en vente sur l'App Store.
- iOS : build 44 envoyé et soumis avec `previous_version=1.0.33`.
