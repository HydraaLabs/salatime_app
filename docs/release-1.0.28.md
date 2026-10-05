# SalaTime 1.0.28 — demande de notation Android et iOS

Android : `1.0.28+33`. iOS : `1.0.28 (38)`.

La demande de notation utilise désormais l'interface native de Google Play
et de l'App Store, sans question préalable. La demande iOS était désactivée.
Les visites courtes comptent maintenant dans les jours d'utilisation, et
une préparation annulée avant l'appel natif ne bloque plus les demandes
pendant 30 jours. Les refus déjà enregistrés sont conservés.

Le bouton de notation des paramètres ouvre la boutique correspondant au
téléphone, même lorsque les réglages du serveur ne fournissent aucun lien.
Les notes et avis restent sous le contrôle de l'utilisateur et de la boutique.

La demande automatique attend trois jours d'utilisation distincts, 72 heures
depuis le premier usage enregistré et dix secondes sur l'accueil visible.
La boutique peut décider de ne pas afficher la fenêtre. Aucun succès de
l'API n'est interprété comme une note envoyée.

Cette livraison contient uniquement le correctif de notation et ses tests.
Les autres modifications locales de recherche, lecture, calendrier et widgets
ne sont pas incluses. Le nouveau plugin nécessite des builds natifs complets.

## Vérification et distribution

Avant préparation de la livraison : analyse Flutter sans erreur, 46 tests
ciblés réussis et APK Android de prévisualisation compilé avec le plugin.
Les preuves finales des builds de production, des envois aux boutiques et
de leur disponibilité seront enregistrées après lecture des services.
Les preuves de compilation ne constituent pas une validation visuelle
de la fenêtre native sur Samsung ou iPhone.
