# SalaTime 1.0.28 — demande de notation Android et iOS

Android : `1.0.28+33`. iOS : `1.0.28 (38)`.

La demande de notation utilise désormais l'interface native de Google Play
et de l'App Store, sans question préalable. La demande iOS était désactivée.
Les visites courtes comptent maintenant dans les jours d'utilisation, et
une préparation annulée avant l'appel natif ne bloque plus les demandes
pendant 30 jours. La migration conserve l'ancienneté, les jours d'utilisation
et les refus explicites. Pour les autres utilisateurs, les réservations de
l'ancien dialogue sont remises à zéro avant la première demande native.

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

Avant préparation de la livraison : analyse Flutter sans erreur, 42 tests
du service et du déclenchement réussis après migration, 12 tests de navigation
précédemment réussis et APK Android de prévisualisation compilé avec le plugin.
Les preuves finales des builds de production et des envois aux boutiques
figurent ci-dessous et dans les reçus locaux.
Les preuves de compilation ne constituent pas une validation visuelle
de la fenêtre native sur Samsung ou iPhone.

## Soumission iOS

Le workflow `ios-release.yml` vérifie le numéro de build auprès d'Apple,
compile et signe l'application, envoie le build exact, attend son traitement
et soumet la version `1.0.28` avec publication automatique après approbation.
Il vérifie la conservation des descriptions, captures et informations privées
de revue. Les reçus ne contiennent aucune clé ou information de connexion.

Si le build est déjà envoyé mais que le traitement ou la soumission reste
en attente, utiliser `resume_submission=true`, `submit_to_app_store=true`,
`upload_to_testflight=false` et le même numéro de build. Ce mode reprend
uniquement la soumission du build existant, sans nouvelle compilation ou upload.

## Publication vérifiée le 5 octobre 2026

- Source Android isolée : `48bfe73b51684e19c693d154a7df4b64f10b1bbb`.
  Les changements ultérieurs concernent uniquement l'outillage iOS et cette documentation.
- Android : 681 tests Flutter réussis. Bundle `net.salatime.app`, `1.0.28+33`,
  trois ABI, plugin natif de notation et 1 861 ressources vérifiés.
- AAB : 139 860 052 octets ; SHA-256
  `49972a66a3a4b95b7f65a7c33971ebd229939b3cff5dfc27219654b62a0a221d`.
- Shorebird : release `877341` active ; bundle distant et trois bases AOT
  téléchargés et identiques aux fichiers publiés sur Google Play.
- Google Play : version `1.0.28 (33)` envoyée et confirmée en production par
  l'API (`completed`). Les autres tracks, dix fiches, images et détails sont
  conservés. La disponibilité du téléchargement Play reste à confirmer.
- APK : 160 296 766 octets ; SHA-256
  `1e7f97c918e6f5435dc7214de8c568ff1df72ec6b085adf66f04b38ba93b428a`.
  Les trois liens ci-dessous ont répondu HTTP 200 et ont été retéléchargés
  intégralement avec le même hash. Les onze fichiers protégés du site restent
  inchangés et des sauvegardes des anciens APK sont conservées.

[APK versionné](https://salatime.net/dl/SalaTime-1.0.28-33.apk),
[APK principal](https://salatime.net/dl/salatime.apk),
[Alias APK](https://salatime.net/app-release.apk).

L'installation directe d'un APK ne prouve pas l'éligibilité à la fenêtre
Google Play. Les conditions du compte Play, les avis déjà existants et
les quotas restent sous le contrôle de Google.

- iOS : compilation simulateur, tests natifs, analyse et tests Flutter,
  archive signée, IPA et extension WidgetKit vérifiés dans le
  [run de distribution](https://github.com/HydraaLabs/salatime_app/actions/runs/37356943537).
- Apple : build `1.0.28 (38)` accepté et traité `VALID`. Version App Store
  `1.0.28` créée avec publication automatique après approbation.
- Soumission confirmée par une lecture Apple : version et soumission
  `WAITING_FOR_REVIEW`, build exact `38`, publication `AFTER_APPROVAL`.
  L'App Store public propose encore `1.0.27` ; la disponibilité de `1.0.28`
  dépend de l'approbation Apple.
- Les descriptions et 36 captures FR/EN/AR, les informations privées de revue
  et le compte de démonstration sont conservés. La pièce jointe historique
  reste sur la version précédente, avec des notes explicites pour la nouvelle.
- Seize auto-tests de l'outillage de soumission réussissent. Les notes de revue
  conservent les informations essentielles, les liens et les limitations
  dans 3 637 octets UTF-8, sous la limite Apple de 4 000 octets.

Les reçus détaillés sont locaux dans `release-artifacts/rating-20261005/`,
avec les hashes, captures d'état et preuves de conservation. Aucun résultat
de compilation ou de tests ne constitue une preuve d'affichage du dialogue
Google/Apple sur un téléphone physique.
