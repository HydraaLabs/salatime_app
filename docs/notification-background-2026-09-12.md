# Réglages réactifs et sauvegarde différée

Les changements de notifications sont enregistrés localement avant de rendre les commandes disponibles. La page ne reste plus bloquée pendant la reprogrammation Android ou la synchronisation du compte.

## Comportement

- Réponse visuelle immédiate ; seul l’enregistrement local est attendu.
- Reprogrammation passive, en arrière-plan, regroupée sur une courte fenêtre de 250 ms. Une nouvelle modification pendant une passe invalide les opérations devenues anciennes et entraîne l’application des dernières valeurs.
- Conservation des annulations et ajouts déjà effectués lors d’une passe interrompue ; aucune file de recalculs identiques à attendre.
- Opérations natives `update`, `route`, `routeAll`, `cancel` et `cancelAll` exécutées dans une file dédiée, hors du thread Android des interactions. Réponses renvoyées sur le thread principal.
- Sauvegarde cloud automatique **60 secondes après le dernier changement**. Chaque nouvelle modification relance la minute. Le contrôle périodique et la reprise de l’application ne raccourcissent pas ce délai.
- Copie locale persistante des préférences, y compris hors connexion. L’action volontaire « synchroniser maintenant » reste immédiate.
- Les pages avant/à/après l’adhan, les autres rappels et les cloches de l’accueil utilisent le traitement non bloquant. Les sons, délais et activations choisis restent identiques.

## Vérification

Les tests couvrent les commandes utilisables pendant une reprogrammation lente, les modifications successives, les erreurs tardives après navigation, la fusion des réglages locaux et la reprise d’une reprogrammation interrompue. Le délai cloud est contrôlé avec une horloge simulée, y compris les modifications en cours de requête et la mise en arrière-plan.

## Livraison

Cette tranche reste locale : aucune publication Play Store ou Shorebird, aucun push ni déploiement du backend.


## Résultats finaux

- Analyse Flutter sans anomalie ; **254 tests Flutter réussis** et **89 tests Android réussis**.
- Le sous-ensemble cloud couvre 39 tests, dont le délai complet de 60 s, la reprise et la préservation des modifications pendant une restauration.
- APK mis à jour sur le Samsung SM-S901U / Android 12 dans **SalaTime Test** (`net.salatime.app.preview`).
- Deux bascules successives après Fajr : sauvegarde locale en **0,112 s puis 0,115 s**, sans attendre la programmation.
- Essai avec une reprogrammation déjà lancée : **0,117 s puis 0,299 s** ; navigation immédiate vers le menu pendant le travail restant.
- Le dernier choix est conservé : après Fajr réactivé, 27 occurrences présentes dans le manifeste et le cache natif. État final : 393 notifications de prière et 57 rappels supplémentaires ; aucun échec de programmation signalé.
- Les vérifications du délai cloud utilisent une horloge simulée et des services de test ; aucun envoi de préférences vers un compte réel ni modification du backend de production.
- Réglage temporaire de maintien en veille USB restauré à sa valeur initiale, fichier de contrôle de l’interface retiré du téléphone.

Les mesures comprennent le transfert de la commande ADB et la lecture du fichier de préférences ; elles portent sur l’enregistrement local, pas sur la durée totale du recalcul des alarmes.

APK installé : `/home/hemiad/Downloads/SalaTime-test-1.0.15-18.apk`.
SHA-256 : `2dfa63c671b17a4ef1b84deb741915d2cb1a133279d69b7bdeb502f399bb832a`.

AAB local : `build/app/outputs/bundle/release/app-release.aab`.
SHA-256 : `384a8bbd16753ec81ba5dcb233ddab633dcb388f3d2d0b5456ae0b0ea45876a9`.

Ces livrables remplacent ceux de la tranche de remplacement des notifications. Aucun fichier n’a été publié.
