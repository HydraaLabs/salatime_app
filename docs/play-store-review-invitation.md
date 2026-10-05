# Demande native de notation sur Android et iOS

SalaTime utilise `in_app_review` pour demander une note avec l'interface native
de Google Play ou de l'App Store. Aucune invitation personnalisée automatique,
question de satisfaction ou sélection selon l'opinion ne précède cette demande.
Le système décide de l'affichage : un appel réussi ne prouve ni que la fenêtre
est apparue, ni qu'une note ou un avis a été envoyé.

Apple demande d'utiliser l'API fournie et interdit les fenêtres personnalisées
de demande d'avis. Google interdit les questions d'opinion avant la carte de
notation. Les deux plateformes recommandent une fiche de boutique pour un
bouton explicite, car leurs quotas peuvent rendre une demande native silencieuse :

- [Apple, règle 5.6.1](https://developer.apple.com/app-store/review/guidelines/#app-store-reviews)
- [Apple, demande native et lien permanent](https://developer.apple.com/documentation/storekit/appstore/requestreview%28in%3A%29-1q8qs)
- [Google, moment de la demande et quotas](https://developer.android.com/guide/playcore/in-app-review#when-to-request)

## Déclenchement automatique

- Android et iOS, application principale `net.salatime.app` uniquement par défaut.
  La variante SalaTime Test (`.preview`) et les autres plateformes restent
  désactivées.
- Au moins trois jours calendaires distincts d'utilisation et 72 heures
  écoulées depuis la première utilisation enregistrée par ce mécanisme.
- L'utilisation est enregistrée à l'entrée ou à la reprise de la navigation
  principale au premier plan. Elle ne dépend pas de 30 secondes ininterrompues
  sur l'accueil : changer d'onglet ne fait plus perdre la journée d'utilisation.
- La présentation attend dix secondes sur l'accueil, application au premier
  plan et route visible. Pas de demande sur les autres onglets, pendant une
  lecture, pendant l'onboarding ou sous un dialogue ou une autre page.
- Changer d'onglet, ouvrir une autre page ou quitter l'application annule le
  délai de présentation. Le retour à l'accueil lance un nouveau délai.
- Une tentative admissible est réservée avant l'appel natif pour éviter les
  demandes simultanées. Délai de 30 jours entre tentatives ; maximum trois
  tentatives par installation. L'indisponibilité de l'API ne constitue pas une
  demande présentée.
- La fin de l'appel natif n'arrête jamais définitivement les demandes : le
  système ne communique ni l'affichage effectif, ni la note, ni l'envoi d'un avis.
  Les quotas de la boutique s'ajoutent aux délais locaux.

L'historique reste dans SharedPreferences sur l'appareil, exclu de la
synchronisation cloud. Le nombre de jours est plafonné à trois. Aucun historique
détaillé de navigation, contenu de lecture, avis ou nombre d'étoiles n'est stocké
par SalaTime.
L'historique existant, y compris un refus explicite enregistré par l'ancienne
invitation, est conservé. Une réservation annulée avant l'appel natif ou un
appel natif en erreur ne consomme pas de tentative ni de délai de 30 jours.

## Bouton dans les paramètres

« Noter SalaTime » ouvre directement la boutique sur action explicite, sans
dépendre des réglages reçus du serveur :

- Android : `https://play.google.com/store/apps/details?id=net.salatime.app`
- iOS : `https://apps.apple.com/app/id6812923710?action=write-review`

Une ouverture réussie arrête les demandes automatiques sur cet appareil. Cela
ne signifie pas qu'une note ou un avis a été envoyé. Une ouverture impossible
affiche un message localisé et laisse le bouton réessayable.

## Compilation et vérification

L'ajout du plugin natif nécessite de nouveaux builds complets Android et iOS.
Une mise à jour Dart seule, notamment un patch Shorebird d'un ancien build sans
ce plugin, ne suffit pas. Ces changements locaux ne publient aucune version.

Les tests de service et de widgets simulent les appels natifs et le lancement
de la boutique pour vérifier les seuils, jours distincts, délais, concurrence,
annulations, changements de visibilité, destinations et erreurs. Leur réussite
ne garantit pas qu'une fenêtre native apparaît sur un appareil physique.

- Android : Google Play doit être installé, l'application doit être accessible
  dans une piste Play et le compte doit pouvoir la noter. Une installation
  locale seule ne suffit pas à valider la fenêtre. Les pistes de test internes
  permettent la vérification sans publication en production ; le partage
  interne affiche une interface dont l'envoi d'avis est désactivé.
- iOS : la fenêtre peut être vérifiée dans un build de développement ou un
  simulateur, avec l'envoi désactivé. L'API ne présente aucune fenêtre dans
  TestFlight. Dans une version App Store, Apple décide si elle est affichée et
  limite les demandes à trois par période de 365 jours. Le bouton ouvrant la
  fiche App Store doit être vérifié sur un appareil physique.

Les preuves de compilation, tests automatisés, installation, affichage physique
et publication restent distinctes. Aucun avis réel n'est envoyé par les tests.

- [Google, tester les demandes natives](https://developer.android.com/guide/playcore/in-app-review/test)
- [Plugin Flutter, usage et restrictions de test](https://pub.dev/packages/in_app_review)

## Vérifications locales du 5 octobre 2026

- Analyse Flutter globale : aucune anomalie.
- 46 tests ciblés réussis : service, déclenchement dans la navigation,
  navigation existante Android/iOS et pont vers le plugin natif.
- APK de validation Android compilé en debug pour `arm64-v8a` :
  `net.salatime.app.preview`, version `1.0.27`, build `32`. Le plugin natif
  de notation est présent dans le DEX. Cette variante conserve la demande
  automatique désactivée ; elle valide la compilation et l'intégration.
- Aucune installation ou validation visuelle sur téléphone effectuée pour
  ce correctif. Compilation iOS non vérifiée sur cet hôte Linux.
- Aucun push, patch Shorebird ou envoi aux boutiques effectué.
