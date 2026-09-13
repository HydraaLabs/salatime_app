# Invitation à donner un avis sur Google Play

L'invitation utilise le thème et les dix langues de SalaTime. Elle propose
« Donner mon avis », « Plus tard » et « Non merci ». Elle n'évalue pas la
satisfaction et ne sélectionne pas les utilisateurs selon leur opinion.

Google Play demande de ne pas poser de question d'opinion avant le bouton ou
la carte de notation. Un bouton explicite doit ouvrir la fiche Play plutôt que
l'API native, dont le quota peut empêcher l'affichage :
https://developer.android.com/guide/playcore/in-app-review#when-to-request

## Déclenchement

- Android, application principale `net.salatime.app` uniquement ; invitation
  automatique désactivée dans SalaTime Test (`.preview`) et sur iOS.
- Au moins 7 jours écoulés depuis la première visite admissible après cette
  mise à jour, et au moins 3 jours calendaires distincts d'utilisation.
- Une visite admissible correspond à 30 secondes continues sur l'accueil,
  application au premier plan et route visible. Pas de demande sur les onglets
  Athkar, Qibla, Mosquées, Plus, pendant une lecture ou pendant l'onboarding.
- Changer d'onglet, ouvrir une autre page, afficher un dialogue ou quitter
  l'application annule le délai. Le retour à l'accueil lance un nouveau délai.
- Une tentative est enregistrée avant l'affichage. « Plus tard », Retour et
  fermeture extérieure repoussent la prochaine possibilité de 30 jours.
  Maximum trois invitations par installation.
- « Non merci » arrête définitivement les invitations automatiques.
- « Donner mon avis » ouvre, sur action explicite, la fiche de production
  `https://play.google.com/store/apps/details?id=net.salatime.app`.
  Une ouverture réussie arrête aussi les invitations. Elle ne prouve pas qu'un
  avis a été soumis ; aucun avis ni aucune étoile ne sont attribués par SalaTime.
- Une ouverture impossible affiche un message localisé et reste réessayable
  depuis les paramètres. Leur bouton d'avis ne dépend plus de l'API du site.

L'historique est un petit objet local SharedPreferences
`play_store_review_invitation_v1`, exclu de la synchronisation cloud. Le nombre
de jours est plafonné à trois ; aucun historique détaillé de navigation ou
contenu de lecture n'est enregistré. Les lectures et alarmes restent indépendantes.

## Vérifications

Tests de service : seuils, jours distincts, reprise, changements d'horloge,
concurrence, refus, délais, plafond, destination exacte, lancement échoué et
stockage corrompu. Tests de navigation : visibilité, délai, arrière-plan,
routes superposées et résultats asynchrones périmés. Tests du dialogue :
trois actions, Retour/fermeture, français/arabe, clair/sombre, écran 320 px
et texte agrandi à 200 %.

Cette modification n'ajoute aucun SDK natif et ne publie aucune version sur
Google Play ou Shorebird. Les tests utilisent un lanceur simulé et ne soumettent
pas d'avis réels.

## État vérifié le 13 septembre 2026

- Suite Flutter complète : 490 tests réussis. Analyse globale : aucune anomalie.
- APK de prévisualisation : `/home/hemiad/Downloads/SalaTime-test-avis-playstore-1.0.16-19.apk`.
- SHA-256 : `70107edc7ec5bbbf929794fa5b7b055e334c21e1af454e31263a994b26fc0b34` (201644542 octets).
- Mise à jour de `net.salatime.app.preview` sur Samsung SM-S901U réussie,
  empreinte du fichier installé relue et identique. L'application Play reste
  intacte. Le téléphone étant verrouillé, aucune validation visuelle physique
  du dialogue n'est revendiquée ; les scénarios d'affichage utilisent les tests
  de widgets. L'invitation automatique est désactivée dans la prévisualisation.
- Aucun push Git, déploiement web, envoi d'avis, publication Play ou Shorebird.
