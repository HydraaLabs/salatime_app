# SalaTime 1.0.36 — stabilité et mesure du premier lancement

Android : `1.0.36+46`. iOS : `1.0.36 (46)`.

## Contenu

- **SALAMTIME-H** (plantage fatal en 1.0.35 juste après la première
  configuration) : un index d'onglet invalide est ignoré au lieu de faire
  planter l'app ; avertissement Sentry « Ignored bottom tab index » pour en
  trouver l'origine.
- **SALAMTIME-F** : une action de sélection de texte qu'Android ne peut pas
  ouvrir (Facebook) répond « pas de texte » au lieu d'une erreur non gérée.
- Message « position momentanément indisponible » quand le GPS échoue alors
  que la permission est accordée (au lieu de demander la permission).
- Analytics : événements sans paramètre des étapes du premier lancement
  (configuration, notifications, localisation, alarmes) ; Analytics coupé
  sur les appareils Firebase Test Lab (rapports de pré-lancement Google Play).
- Aucune nouvelle autorisation ni collecte de données personnelles.

## Publication

- Base vérifiée le 31 octobre 2026 : 1.0.35 (45) publiée sur Google Play et
  en vente sur l'App Store.
