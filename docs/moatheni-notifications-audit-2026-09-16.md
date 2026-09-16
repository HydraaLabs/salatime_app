# Audit des notifications Moatheni — 16 septembre 2026

Objectif : comparer le fonctionnement des notifications et améliorer la fiabilité de SalaTime, sans changer son design. Les corrections locales et leurs vérifications sont détaillées ci-dessous.

**Suite de cet audit :** [alignement des calculs, des rappels supplémentaires et de la priorité](moatheni-calculation-alignment-2026-09-16.md). Ce second bilan remplace le périmètre « rappels supplémentaires inchangés » et précise les nouveaux canaux de lecture.

## Référence et méthode

- [Fiche Google Play fournie](https://play.google.com/store/apps/details?id=com.mahmoud.android.Adani).
- APK local examiné : `/home/hemiad/Downloads/SalaTime-reference/Moatheni.apk`.
- Paquet : `com.mahmoud.android.Adani` ; version **3.0.5 (63)** ; Android minimum 24, cible 36.
- SHA-256 APK : `24ab1a89bede8d9a31ac77a105e94349bf76c3318b356a477f7d0dd7637169f4`.
- Signature APK vérifiée par `apksigner` ; SHA-256 du certificat : `50d96010a278edba7e869c16febdab5018bf2b4d91ca07ba4bc6d593fc6b1b69`.
- Métadonnées relues avec `aapt dump badging`. L'APK et sa copie `/tmp/salatime-moatheni-audit/moatheni.apk` ont la même empreinte.
- Analyse **statique** du manifeste et des sorties apktool/JADX déjà présentes dans `/tmp/salatime-moatheni-audit/`. Elle décrit cette version locale et ne prouve ni qu'elle est la dernière sur Play, ni son comportement réel sur un téléphone.
- Les conclusions portent sur les API et comportements observés. Aucun code ni nouvel asset de la référence n'est repris dans cette tranche.

## Fonctionnement observé dans Moatheni

Les sources ci-dessous sont relatives à `/tmp/salatime-moatheni-audit/jadx/sources/com/mahmoud/android/Adani/util/`.

| Mécanisme | Observation | Preuve statique |
|---|---|---|
| Planification | Reconstruit trois jours d'alertes ; ignore les dates déjà passées et certains doublons | `NotificationManager.java`, `scheduleNotifications`, `createNotification` |
| Déclenchement | Utilise `AlarmManager.setAlarmClock` pour les alertes avant/à/après et les rappels supplémentaires, si l'autorisation exacte est disponible | `NotificationManager.java`, `createNotification` |
| Autonomie | Renouvelle la fenêtre après une alerte et lors du passage en arrière-plan/de la sortie | `NotificationReceiver.java`, fin de `onReceive` ; `App.java`, `setupBackgroundStuff` |
| Phases | Activation, son et décalage indépendants ; Sunrise et Jumu'ah sont identifiés séparément | `NotificationManager.java`, `createPrayerNotifications`, `getValuesForKey` |
| Son | Son porté par le canal Android, importance haute, `USAGE_NOTIFICATION` ; aucun service dédié à la lecture de l'adhan observé | `NotificationReceiver.java`, `createNotificationsChannel` ; manifeste |
| Affichage | Alerte sonore ID=1, expiration après cinq minutes, badge désactivé ; notification permanente distincte | `NotificationReceiver.java`, `onReceive`, `createPermanentNotification` |
| Permissions | Vérifie notifications, alarmes exactes et optimisation batterie ; propose les réglages Android correspondants | `PermissionManager.java` |
| Heure/reboot | `TIME_SET` relance les calculs ; `BOOT_COMPLETED` est déclaré pour plusieurs receivers | `TimeChangedReceiver2.java` ; `/tmp/salatime-moatheni-audit/resources/AndroidManifest.xml` |
| Retard | Aucun filtre de retard observé dans la réception d'une alerte déjà programmée | `NotificationReceiver.java`, `onReceive` |

La déclaration d'un receiver BOOT ne suffit pas à démontrer une restauration complète des alertes : le chemin sans données de `NotificationReceiver` crée surtout la notification permanente. Aucun essai de redémarrage Moatheni n'est revendiqué ici.

## Comparaison avec SalaTime avant les corrections de cette tranche

| Sujet | État observé dans SalaTime | Conséquence |
|---|---|---|
| Adhan à l'heure | `setAlarmClock` est déjà employé par la couche native | Principe principal déjà aligné |
| Avant/après | `setExactAndAllowWhileIdle` | Des alertes rapprochées peuvent être retardées en Doze, puis expirer selon la tolérance SalaTime |
| Audio | Service natif avec lecture contrôlable, arrêt et respect du silence | Conserver ces contrôles ; vérifier également la permission pendant la lecture |
| Restauration | Reboot, mise à jour, heure, fuseau et permission exacte sont traités | Conserver la restauration et la suppression des occurrences périmées |
| Retards | Adhan tardif silencieux ; rappels périmés ignorés | Évite une succession de sons anciens à la reprise |
| Renouvellement | Fenêtre calculée côté Flutter ; pas de prolongation dans le receiver natif observé | Ne pas annoncer une autonomie illimitée sans réouverture |

Sources SalaTime :

- `android/app/src/main/java/com/dexterous/flutterlocalnotifications/SalaTimePrayerAlarms.java` : enregistrement, tolérance et diagnostic.
- `android/app/src/main/java/com/dexterous/flutterlocalnotifications/SalaTimePrayerAlarmReceiver.java` : réception et sélection du mode de livraison.
- `android/app/src/main/java/com/dexterous/flutterlocalnotifications/SalaTimeAlarmRestoreReceiver.java` : restauration et nettoyage du cache.
- `android/app/src/main/java/com/dexterous/flutterlocalnotifications/SalaTimeAdhanService.java` : lecture native.
- `android/app/src/main/java/com/dexterous/flutterlocalnotifications/SalaTimeNotificationTray.java` : remplacement et expiration des notifications.
- `lib/helper/salat_waqt_service.dart` et `lib/helper/prayer_alarm_plan.dart` : construction de la fenêtre et budget partagé d'alarmes.

Android documente que les alarmes `setAlarmClock` continuent normalement en Doze, tandis que les méthodes `allowWhileIdle` ont des limites de fréquence. L'écart constitue donc un risque étayé ; il ne constitue pas une panne reproduite sur appareil. [Documentation Android](https://developer.android.com/training/monitoring-device-state/doze-standby)

## Corrections réalisées dans cette tranche

1. `setAlarmClock` couvre désormais les phases de prière **avant/à/après**, avec un raccourci ouvrant l'application et le repli existant lorsque les alarmes exactes ne sont pas autorisées. Les rappels supplémentaires conservent leur stratégie actuelle. Android peut donc afficher un rappel avant/iqama comme prochaine alarme système ; chaque phase demeure annulable indépendamment.
2. La liste **Alarmes à venir** et les prières ignorées reconnaissent le **lever du soleil** (qui provoquait un dépassement d'index) et affichent **Joumou‘a le vendredi**, Dohr les autres jours. Les entrées mémorisées invalides sont filtrées sans faire planter la liste.
3. La permission de notifications et les réglages sonores du canal sont revérifiés après la préparation audio et pendant la lecture. Leur désactivation empêche ou arrête l'adhan et libère les ressources ; leur réactivation ne relance pas l'ancienne occurrence. Le contrôle existant toutes les 250 ms est réutilisé, sans ouvrir les fichiers audio.

Aucun changement de design, import de son/image, push, déploiement ou publication n'a été effectué dans cette tranche. Les modifications préexistantes et concurrentes du dépôt ont été conservées.

## Limites conservées

- SalaTime prépare jusqu'à 30 jours, avec la veille pour les rappels chevauchant minuit, et partage un budget maximal de 450 alarmes Android entre prières et rappels ; les choix activés influencent sa couverture effective. Le receiver natif ne recrée pas une fenêtre de calcul complète après chaque alerte.
- Une restauration remet en place les occurrences futures déjà connues ; elle ne démontre pas un renouvellement permanent hors ouverture de l'application.
- Pour un calendrier manuel hors connexion sans les journées nécessaires, les rappels supplémentaires futurs connus peuvent être conservés. Leur décalage/son ne peut pas être garanti recalculé immédiatement pour les dates non couvertes ; les préférences sont sauvegardées et la désactivation est prise en compte. Ce cas reste distinct de la reconstruction des prières à partir de leurs instants mémorisés.
- Les comportements constructeur, le verrouillage, Doze, le retrait de permissions et l'arrêt forcé nécessitent une vérification sur téléphone. L'analyse statique et les tests unitaires ne la remplacent pas.

## Validation de la tranche

- Analyse Flutter complète : **aucun problème**, `flutter analyze --no-pub`.
- Flutter : **18 tests réussis**, `test/view/upcoming_prayer_alarms_test.dart` et `test/helper/prayer_notification_scheduler_test.dart` ; lever du soleil, vendredi, cache invalide et programmation existante couverts.
- Android : **170 tests réussis, aucun échec/erreur**, suites de `com.dexterous.flutterlocalnotifications.*`, `AdhanVolumeKeyDispatcherTest` et `PrayerScheduleBackgroundHandlerTest` sur les SDK simulés déclarés par les tests (notamment 24 et 33).
- Le nouveau test des phases rapprochées échouait avant correction, puis passe. Il vérifie avant à −5 min / adhan / après à +3 min, annulations indépendantes, raccourci ouvrant l'app et repli sans permission exacte. Les tests ne simulent pas le throttling réel du constructeur.
- Huit nouveaux cas natifs vérifient le retrait des permissions pendant la préparation/lecture, la libération du lecteur, de l'audio focus et du verrou de veille, et l'absence de redémarrage du son.
- Journaux locaux : `/tmp/salatime-reference-native-before.log`, `/tmp/salatime-reference-native-after.log`, `/tmp/salatime-reference-native-final.log`, `/tmp/salatime-reference-analyze.log`.
- Contrôle `git diff --check` : sans erreur.
- Appareil : `adb devices -l` ne présente aucun appareil. Aucun test physique ni écoute réelle effectué dans cette tranche ; la comparaison Moatheni reste statique.
- APK de test construit avec `ORG_GRADLE_PROJECT_salatimePreview=true flutter build apk --debug --no-pub --target-platform android-arm64` ; signature vérifiée par `apksigner`, paquet relu par `aapt2` : **SalaTime Test**, `net.salatime.app.preview`, `1.0.21+24`, cible Android 36. Ce paquet s'installe séparément de la version Play.
- Livrable local : `build/reference-audit/SalaTime-test-notifications-2026-09-16.apk` (**212 834 215 octets**), SHA-256 `b592ee189ac2ede12b0f6244d5e38c84d4eac48b7875c8933f80326a77909c2d`. L'APK contient l'état local du dépôt, y compris les changements déjà présents au début de cette tranche ; aucun nouveau numéro de version/publication n'a été créé.
