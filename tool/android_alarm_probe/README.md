# Sonde Android isolée

Cette instrumentation Java utilise uniquement le SDK Android. Elle cible **exclusivement** `net.salatime.app.preview`, sans écran et sans modification du build Gradle principal. Sa signature debug doit correspondre à celle de l'APK Preview installé. Elle appelle les API natives existantes par réflexion, avec le modèle du plugin déjà présent dans l'application.

## Préparation locale

```bash
python3 tool/android_alarm_probe/probe.py build --out /tmp/salatime-alarm-probe
```

Cette commande compile et signe localement ; elle n'installe et ne lance rien. Après installation volontaire de l'APK Preview souhaité, installer séparément `/tmp/salatime-alarm-probe/alarm-probe.apk` avec `adb install -r`. Ne pas lancer la sonde pendant une lecture audio ou une modification de réglage en cours.

## État réel, sans démarrer l'application

```bash
python3 tool/android_alarm_probe/probe.py observe --serial R5CT10WZLWF --alarms --output /tmp/salatime-three-day-device/before.json
```

La commande ne lit que les fichiers horaires/notifications autorisés via `run-as`. Elle affiche des agrégats et quelques clés de diagnostic ; elle ne restitue ni les autres préférences ni les notifications d'autres applications. Elle compte les alarmes Android réellement armées, distinctes de la réserve en cache. Les horaires agrégés sont en UTC, avec l'heure locale du téléphone en complément.

## Test volontaire d'un démarrage à froid

1. Relever l'état avec `observe`, puis `invoke --mode status`. Vérifier que les réglages actuels permettent le résultat attendu. Ne jamais changer automatiquement le volume, le mode sonnerie, DND ou les permissions. Un résultat `audio_muted` valide le respect du silence, pas un essai sonore.
2. Planifier explicitement le test :

```bash
python3 tool/android_alarm_probe/probe.py invoke --serial R5CT10WZLWF --mode schedule --delay 60 --sound noti_beep_beep
```

3. L'instrumentation se termine. Pour vérifier le processus froid sans arrêt forcé : `adb -s R5CT10WZLWF shell am kill net.salatime.app.preview`, puis vérifier l'absence de PID avec `observe`. Ne pas employer `force-stop` : il supprime le scénario que l'on cherche à tester. S'il reste un service et un PID, ne pas prétendre avoir testé un démarrage à froid.
4. Mettre volontairement l'écran en veille **avant** le déclenchement, par exemple avec `adb -s R5CT10WZLWF shell input keyevent 223`. Ne pas utiliser la bascule Power, qui peut réveiller un écran déjà éteint.
5. Lire `observe` juste après l'échéance et après la fin du son. Cela utilise `run-as`, sans démarrer l'activité ni une nouvelle instrumentation. `delivery_is_probe=true`, `plannedAt`, `deliveredAt`, `delayMs` et `outcome` identifient la réception de ce test.
6. Pour observer un service actif plus longtemps, `noti_1` dure environ 29,5 secondes dans les assets actuels ; les deux sons beep durent environ deux secondes. Ce choix nécessite un essai sonore volontaire. La sonde respecte les réglages existants et ne force aucune sortie audio.
7. **Après la fin de l'audio seulement**, `invoke --mode status` permet de vérifier le canal de lecture `playbackChannelImportance=4` (HIGH). Démarrer une instrumentation pendant la lecture pourrait redémarrer le processus cible et fausser l'essai. Le niveau du canal prouve sa configuration ; une apparition heads-up reste à observer sur l'appareil.

La planification crée uniquement le test ID `1999000001`, marqué `test=true`, avec un canal source dédié. Elle refuse un ID déjà utilisé, une sonde non nettoyée, une notification de rappel active, un service visible ou une vraie alarme à moins de deux minutes après le test. Elle n'emprunte pas les sons personnels. Le clone d'une occurrence existante conserve le format natif du plugin ; ce chemin teste l'adaptateur Android, pas la planification Flutter.

## Maintenance à l'heure réelle

```bash
python3 tool/android_alarm_probe/probe.py invoke --serial R5CT10WZLWF --mode renew
```

Cette commande appelle `maintainWindow` avec l'heure réelle du téléphone. Elle ne modifie pas l'horloge et n'imite pas un changement de date. Comparer `observe --alarms` avant/après ; un passage idempotent doit garder la réserve et la fenêtre cohérentes. Ne pas lancer cette instrumentation pendant le test audio.

## Nettoyage ciblé

```bash
python3 tool/android_alarm_probe/probe.py invoke --serial R5CT10WZLWF --mode cleanup
python3 tool/android_alarm_probe/probe.py observe --serial R5CT10WZLWF --alarms
adb -s R5CT10WZLWF uninstall net.salatime.alarmprobe
```

Le nettoyage annule uniquement l'ID de sonde et son éventuelle notification identifiée, retire son canal source et sa sauvegarde privée. Il restaure les mesures de livraison précédentes **uniquement si elles correspondent encore à l'instant de cette sonde** ; une vraie livraison ultérieure reste intacte. Il ne remplace jamais le cache complet ou les réglages utilisateur. Le canal partagé de lecture introduit par l'application est conservé. Le nettoyage ne réveille pas l'écran et ne modifie pas le mode silencieux.

Conserver les références et résultats appareil sous `/tmp`, hors dépôt. Une compilation réussie de cette sonde n'est pas une validation sur téléphone.
