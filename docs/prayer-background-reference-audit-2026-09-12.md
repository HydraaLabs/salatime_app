# Fiabilité en arrière-plan : comparaison du code et correctif

## Objet et sources vérifiées

L’objectif initial était de prévenir les alarmes absentes ou retardées en
s’inspirant d’apps Android open source. Les tests de l’interface et de la
programmation seuls ne validaient pas le passage de l’alarme au lecteur ni
une nuit de veille sur Samsung. Cet audit complète ces vérifications.

Code consulté le 12 septembre 2026, sans exécuter les projets tiers ni en
transplanter les fichiers dans SalaTime :

- **Al-Azan Compose**, AGPL-3.0, commit
  [`b9405c3370a87d0db5795c35d0c8c1c27e3ba645`](https://github.com/meypod/al-azan-compose/tree/b9405c3370a87d0db5795c35d0c8c1c27e3ba645),
  daté du 12 août 2026. Programmation, réception, lecture et restauration lues.
- **Five Prayers**, GPL-3.0, commit
  [`cb02f437a79cc73361e96abd829efe327cecb8f6`](https://github.com/Five-Prayers/five-prayers-android/tree/cb02f437a79cc73361e96abd829efe327cecb8f6),
  daté du 5 septembre 2023. Cette référence ancienne permet de comparer des
  mécanismes ; elle n’établit pas une meilleure compatibilité avec Android actuel.

## Comparaison

| Point | Al-Azan Compose | Five Prayers | SalaTime 1.0.14 |
| --- | --- | --- | --- |
| Déclenchement | `AlarmClock` par défaut, option `ExactAllowWhileIdle`. [A](#sources) | `setExactAndAllowWhileIdle` sur Android 6+. [D](#sources) | `setAlarmClock` pour l’adhan ; rappels exacts pendant la veille si autorisés. Récepteur marqué prioritaire. |
| Lecture | Service au premier plan, `MediaPlayer`, volume des alarmes et protection de veille du lecteur. [B](#sources) | `MediaPlayer` avec `USAGE_ALARM`. [E](#sources) | Service temporaire, son choisi, volume des alarmes, arrêt et libération des ressources. |
| Prière suivante | Reprogrammation après chaque adhan. [C](#sources) | Travail périodique de renouvellement toutes les 30 minutes. [F](#sources) | Jusqu’à 30 jours préprogrammés, renouvelés à l’ouverture/reprise et aux changements de réglages. |
| Redémarrage et permission exacte | Recalcul via `SchedulerReconciler`, traitement séparé des prières manquées. [G](#sources) | Récepteur de redémarrage et ordonnanceur de prières. [H](#sources) | Cache persistant, retrait des échéances passées, restauration des échéances futures et repli sans permission exacte. |

Une comparaison de code ne démontre pas le comportement matériel de ces apps
ou de SalaTime. La fenêtre SalaTime de 30 jours reste une limite connue : le
renouvellement ne doit pas être présenté comme illimité sans ouvrir l’app.

## Écart supplémentaire trouvé et corrigé

Le code 1.0.13 possédait un verrou de veille dans le lecteur, mais aucun relais
entre le retour du récepteur et l’entrée dans le service. La documentation
[`AlarmManager`](https://developer.android.com/reference/android/app/AlarmManager)
précise que la protection système se termine avec le récepteur : le téléphone
peut se rendormir avant le démarrage du service. Il faut protéger cette transition.

Ce risque a été confirmé par un test en échec avant modification, sans prétendre
qu’il constitue la cause prouvée de la capture Samsung antérieure.

`SalaTimeAlarmWakeLock` acquiert désormais un verrou partiel avant de demander
le démarrage du service. Un identifiant unique relie la demande au service,
qui libère ce verrou dans un `finally`, après avoir acquis son propre verrou
de lecture ou abandonné la lecture. Un refus de démarrage libère immédiatement
la protection ; son délai maximal de 60 secondes évite de la garder indéfiniment.

Les identifiants restent uniques après recréation du processus. Une ancienne
demande ne peut donc pas libérer le verrou d’une nouvelle alarme. Le démarrage
du service plus de deux minutes après l’heure prévue produit un avis silencieux
et enregistre maintenant le retard réel du démarrage du lecteur.

Cette protection est temporaire, sans garder l’écran allumé. Elle est écrite
pour SalaTime à partir du contrat Android, sans copie du code AGPL/GPL.
[Recommandations Android sur les verrous de veille](https://developer.android.com/develop/background-work/background-tasks/awake/wakelock).

## Vérifications effectuées

- Avant correction : `coldAlarmKeepsCpuAwakeUntilThePlayerTakesOver` échoue sur
  l’absence de protection au retour du récepteur.
- Après correction : **44 tests Android Robolectric réussis**, dont les cas
  de transition récepteur → service → lecteur sur SDK 24 et 33.
- Protection active pendant le démarrage, puis relais au lecteur ; libération
  des ressources à la fin du son et lorsque le démarrage est refusé.
- Service absent pendant 61 secondes ou reçu trois minutes trop tard :
  protection expirée, aucune lecture tardive et retard enregistré correctement.
- Après redémarrage et mise à jour : prière future restaurée, prière expirée
  retirée, notification étrangère préservée, aucun démarrage audio au rattrapage.
- **79 tests Flutter réussis**, analyse sans problème.

Les horloges du harnais sont simulées : ces tests vérifient les transitions et
leurs effets, pas la politique énergétique réelle de Samsung. `adb devices -l`
ne présente aucun appareil connecté. La réception après une veille prolongée
et une destruction réelle du processus reste à valider sur appareil avant
d’annoncer ce comportement comme vérifié matériellement.

## APK pour essai

- Version `1.0.14+17`, paquet `net.salatime.app`, compilée avec Flutter 3.41.8
  via `flutter build apk --release --no-pub`.
- Signature vérifiée, même certificat que l’APK 1.0.13. Les quatre classes
  Android de programmation/lecture et les trois sons sont présents dans l’APK.
- Taille locale et métadonnées Drive relues : **92 233 096 octets**.
- SHA-256 local : `bd59f814b18dd7dd89409c8a1ff2b7d77cc596ff6606b2388ba7baeae1d63f2b`.
- [APK 1.0.14 sur Google Drive](https://drive.google.com/file/d/1pbUcmE-6UvUi6DOesyyh_lBm2kpyT9nx/view?usp=drivesdk).
- Cette livraison est un APK de test ; aucun envoi de la version 1.0.14+17 à
  Google Play ou Shorebird n’a été réalisé.

## Sources

- A — [AlarmSchedulingDefaults.kt](https://github.com/meypod/al-azan-compose/blob/b9405c3370a87d0db5795c35d0c8c1c27e3ba645/app/src/main/java/com/github/meypod/al_azan/core/domain/model/alarm/AlarmSchedulingDefaults.kt),
  [AlarmRepositoryImpl.kt](https://github.com/meypod/al-azan-compose/blob/b9405c3370a87d0db5795c35d0c8c1c27e3ba645/app/src/main/java/com/github/meypod/al_azan/core/data/repository/AlarmRepositoryImpl.kt).
- B — [PlaybackService.kt](https://github.com/meypod/al-azan-compose/blob/b9405c3370a87d0db5795c35d0c8c1c27e3ba645/app/src/main/java/com/github/meypod/al_azan/playback/PlaybackService.kt).
- C — [AdhanFiringHandler.kt](https://github.com/meypod/al-azan-compose/blob/b9405c3370a87d0db5795c35d0c8c1c27e3ba645/app/src/main/java/com/github/meypod/al_azan/adhan/AdhanFiringHandler.kt).
- D — [PrayerAlarmScheduler.java](https://github.com/Five-Prayers/five-prayers-android/blob/cb02f437a79cc73361e96abd829efe327cecb8f6/app/src/main/java/com/hbouzidi/fiveprayers/notifier/PrayerAlarmScheduler.java).
- E — [AdhanPlayer.java](https://github.com/Five-Prayers/five-prayers-android/blob/cb02f437a79cc73361e96abd829efe327cecb8f6/app/src/main/java/com/hbouzidi/fiveprayers/notifier/AdhanPlayer.java).
- F — [WorkCreator.java](https://github.com/Five-Prayers/five-prayers-android/blob/cb02f437a79cc73361e96abd829efe327cecb8f6/app/src/main/java/com/hbouzidi/fiveprayers/job/WorkCreator.java),
  [PrayerUpdater.java](https://github.com/Five-Prayers/five-prayers-android/blob/cb02f437a79cc73361e96abd829efe327cecb8f6/app/src/main/java/com/hbouzidi/fiveprayers/job/PrayerUpdater.java).
- G — [SchedulerReconciler.kt](https://github.com/meypod/al-azan-compose/blob/b9405c3370a87d0db5795c35d0c8c1c27e3ba645/app/src/main/java/com/github/meypod/al_azan/SchedulerReconciler.kt),
  [BootReceiver.kt](https://github.com/meypod/al-azan-compose/blob/b9405c3370a87d0db5795c35d0c8c1c27e3ba645/app/src/main/java/com/github/meypod/al_azan/BootReceiver.kt),
  [ExactAlarmPermissionReceiver.kt](https://github.com/meypod/al-azan-compose/blob/b9405c3370a87d0db5795c35d0c8c1c27e3ba645/app/src/main/java/com/github/meypod/al_azan/ExactAlarmPermissionReceiver.kt).
- H — [NotifierBootReceiver.java](https://github.com/Five-Prayers/five-prayers-android/blob/cb02f437a79cc73361e96abd829efe327cecb8f6/app/src/main/java/com/hbouzidi/fiveprayers/notifier/NotifierBootReceiver.java).
