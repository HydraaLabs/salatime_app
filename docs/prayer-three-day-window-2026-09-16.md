# Fenêtre Android de trois jours — 16 septembre 2026

Suite de l'[alignement Moatheni](moatheni-calculation-alignment-2026-09-16.md), à la demande de limiter la programmation à trois jours et de vérifier le Samsung connecté. Aucun changement de design ni publication.

## Choix technique

Android ne conserve comme réveils actifs que les occurrences entre maintenant et minuit après le troisième jour, dans le fuseau de prière. La journée en cours compte comme premier jour ; cette borne suit les changements d'heure et n'est pas une durée fixe de 72 heures.

Le cache conserve une réserve calculée allant jusqu'à 30 jours, dans le budget existant de 450 occurrences partagées avec les rappels supplémentaires. Cette réserve n'est pas enregistrée entièrement dans AlarmManager. Les préférences, les corrections et les calculs existants restent la source des horaires : aucun horaire n'est reconduit artificiellement à +24 heures.

Le receiver natif complète la fenêtre lorsque la journée change. Une seule alarme d'entretien quotidienne, inexacte, permet aussi de compléter la fenêtre quand les alertes activées sont espacées. Le renouvellement lit le cache sans réseau et sans moteur Flutter. Les restaurations après redémarrage, mise à jour, changement d'heure ou permission rétablissent aussi cette fenêtre.

La préparation Dart regroupe les ajouts et annulations dans une transaction native. Le cache est écrit une fois par lot, puis les occurrences des trois jours sont armées. La mise à jour du widget évite ensuite un second réarmement si le jour, le fuseau, la permission et le résultat restent valides. Le même verrou protège la consommation d'une alarme et la transaction pour éviter de réintroduire une occurrence déjà reçue. Un remplacement devenu passé supprime l'ancien horaire différent ; une réception simultanée au même instant reste possible. Les notifications appartenant à d'autres fonctionnalités sont conservées.

## Coût et limites

- Le gain recherché concerne le nombre d'alarmes Android et les écritures/échanges effectués pendant la reprogrammation. Cela ne prouve pas une amélioration chiffrée de la batterie ou de la fluidité globale.
- La réserve est finie : ouvrir l'app la prolonge. Selon le calendrier manuel disponible et le nombre de rappels activés, elle peut couvrir moins de 30 jours. Le renouvellement natif ne calcule pas de dates au-delà de cette réserve.
- La restauration rare utilise encore le mécanisme général du plugin avant de retirer les alarmes hors fenêtre ; elle peut donc enregistrer transitoirement la réserve. La rotation quotidienne n'utilise pas ce mécanisme.
- La livraison exacte reste confiée à `setAlarmClock`, avec repli inexact si nécessaire. Diminuer la fenêtre ne diminue pas le nombre d'alertes choisies chaque jour. [Contrats Android et consommation des alarmes](https://developer.android.com/develop/background-work/services/alarms).
- iOS conserve sa programmation existante et son plafond de notifications ; cette fenêtre et ce renouvellement concernent Android.
- Un arrêt forcé Android bloque les réveils jusqu'à la réouverture. Une application simplement retirée de l'écran ou dont le processus est arrêté n'est pas le même cas.

## Validation

- Tests Android : **216 réussis**, aucune erreur ni échec. Fenêtre, DST, consommation simultanée, réserve, restauration, batch atomique, notifications étrangères, annulation, priorité et absence de double réarmement couverts. Journal : `/tmp/salatime-three-day-native-final.log`.
- Tests Flutter complets : **590 réussis**, dont les 25 tests ciblés de batch/planification. Analyse Flutter sans problème. Journaux : `/tmp/salatime-final-flutter.log` et `/tmp/salatime-final-analyze.log`.
- État initial Samsung SM-S901U, Android 12/API 31 : **435 réveils de prière**, plus une transition de notification et un widget, soit **437 alarmes** ; **145 AlarmClock**. Cache : 435 occurrences futures. Mesure agrégée : `/tmp/salatime-three-day-device/before-summary.json`.
- L'APK présent sur le téléphone avant la mise à jour est sauvegardé sous `/tmp/salatime-three-day-device/before-preview.apk`. Les réglages de volume et de silence ne sont pas modifiés pour les essais.

### APK installé et réception sur Samsung

APK construit puis installé avec conservation des données : `build/reference-audit/SalaTime-test-auto-pays-3jours-2026-09-16.apk`, paquet `net.salatime.app.preview`, libellé **SalaTime Test**, version 1.0.21+24. SHA-256 : `1c8e11d2d4c448b7b2065c22d20da32bfe85d976e370445b3b0a953fbd0504e3`. Aucun envoi sur Play, Shorebird ou Git.

Après ouverture le 16 septembre à 23:56, il reste **30 réveils de prière actifs**, tous AlarmClock, plus un entretien et un widget : **32 alarmes au total**. Le cache garde **435 occurrences futures** jusqu'au 15 octobre. Le chiffre de 30 dépend de l'heure de mesure : les prières du jour étant passées, seuls les deux jours suivants occupent la fenêtre. Les indicateurs de planification sont sans échec ni repli inexact. Mesure : `/tmp/salatime-three-day-device/after-launch.json`.

La sonde isolée `tool/android_alarm_probe` a programmé une seule occurrence de test à **23:58:06.543**. Avant l'échéance, aucun processus de l'application n'était présent et l'écran était en veille. Le receiver a reçu l'alarme à **23:58:07.491**, soit **948 ms de retard**, et consommé son entrée du cache. Résultat : `audio_muted`, conforme au mode silencieux déjà actif. Preuves : `/tmp/salatime-three-day-device/probe-cold-before.json` et `probe-after-delivery.json`.

Cette réception valide le réveil natif avec processus arrêté et écran en veille. Elle ne valide ni une sortie sonore audible, ni l'apparition d'une bannière, ni un mode Doze profond forcé : la tentative de passage en veille profonde a été refusée par l'appareil, puis annulée avec `deviceidle unforce`. Aucun réglage de son, de batterie ou de permission n'a été changé.

### Rotation au changement de jour et nettoyage

À 00:02:08 le 17 septembre, l'entretien inexact de minuit était encore en attente. L'état natif a ensuite enregistré le renouvellement à **00:02:09.469**, avec une borne avancée du 19 au **20 septembre à minuit**. La lecture `status` a constaté **45 réveils armés** avant l'appel explicite `renew` de la sonde ; cet appel ultérieur à l'heure réelle n'a changé ni le nombre ni l'instant du renouvellement. Aucune activité Flutter n'a été ouverte depuis le test. Le délai de l'entretien est compatible avec sa programmation inexacte ; il ne décale pas les prières déjà armées.

Le relevé AlarmManager `after-midnight-renewal.json` confirme **45 AlarmClock de prière**, plus un entretien et un widget, soit **47 alarmes au total**, pour **435 occurrences conservées en réserve**. Les trois journées actives sont maintenant les 17, 18 et 19 septembre. Le processus est absent lors du relevé à 00:02:35.

La sonde a été nettoyée puis désinstallée. Ses mesures temporaires ont été remplacées par les mesures de livraison antérieures, son ID et son canal source ont été retirés. Le relevé final `/tmp/salatime-three-day-device/final-clean.json` à 00:03:10 confirme l'absence de sonde, les 45 réveils de prière et la réserve inchangée. Le mode silencieux a été conservé.
