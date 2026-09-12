# Vérification de l’ajusteur de prière — 12 septembre 2026

Demande : vérifier le fonctionnement des boutons +/− et la propagation des
décalages. Les modifications restent locales, sans publication.

## Corrections

- L’écran attend seulement la persistance locale, puis demande un recalcul
  passif en arrière-plan. Aucun GPS, accès réseau ni demande d’autorisation ne
  doit être déclenché par un appui sur +/−.
- Chaque édition relance le délai de synchronisation cloud : une minute après
  le dernier changement. Les horaires ajustés restent disponibles immédiatement.
- Les lectures, écritures et remises à zéro sont sérialisées, même entre deux
  contrôleurs. Les décalages sont validés entre −120 et +120 minutes. Un échec
  de stockage restaure la valeur précédente ; un JSON partiellement invalide
  conserve ses entrées valides sans effacement à la lecture.
- L’accueil classique applique maintenant les décalages aussi aux horaires
  d’une ville choisie manuellement et au lever du soleil. Il observe les
  modifications du contrôleur d’ajustement. Le modèle horaire de base reste intact.
- Le registre des alarmes conserve le décalage utilisé avec chaque horaire.
  Cela permet de réajuster un horaire retrouvé dans ce registre lorsque son
  calendrier n’est plus en cache, sans cumuler plusieurs fois les minutes.
  Un ancien registre sans cette métadonnée garde son instant historique tant
  qu’un calendrier fiable n’est pas disponible : sa base ne peut pas être déduite.
- Les libellés de fin du souhour et début de l’iftar utilisent les traductions
  existantes.

## Vérification

Les tests couvrent les appuis pendant une programmation bloquée, la sauvegarde
et les erreurs disque, les bornes, les restaurations cloud, les horaires manuels,
les six horaires et leurs trois phases de notification, la remise à zéro et
les passages à minuit. Les tests du pont natif vérifient les arguments planifiés,
sans prouver le déclenchement physique d’AlarmManager sur Samsung.

Résultat : 128 tests réussis (50 régressions affichage/planification, 40 tests
du service de notifications et de la synchronisation cloud, 19 tests de
persistance, 11 tests de l’écran, 8 tests d’intégration de la planification).
Analyse ciblée sans anomalie. Affichage contrôlé à 320 px avec texte à 200 %
en français et en arabe, thèmes clair et sombre.

Exemple vérifié : Assr 16:48 + 5 minutes = 16:53 ; lever du soleil 07:01 − 2
minutes = 06:59. Une nouvelle lecture ne cumule pas à nouveau ces décalages.

## Version de test

APK ARM64 de débogage, version 1.0.15+18, paquet `net.salatime.app.preview`,
API de compte `https://salatime.net`.

Fichier : `/home/hemiad/Downloads/SalaTime-test-ajustements-1.0.15-18.apk`.

SHA-256 : `9bd9fe3b05e4a4d05a233a3ab6b228cf97e42bd1a4f481fc1743b55aeddbc60a`.

Installation `adb install -r` réussie sur Samsung SM-S901U, sans désinstallation
ni remplacement de l’application Play. Contrôle réel dans l’écran : Assr 16:48
à 0 minute, appui + donnant 16:49 à 1 minute, puis appui − restaurant 16:48 à
0 minute. Après restauration, stockage local `prayerAdjustments = {}` et
indicateur `prayer_alarm_failed_v2 = false`. Aucun adhan n’a été déclenché pour
ce contrôle ; les préférences initiales ont été rétablies.
