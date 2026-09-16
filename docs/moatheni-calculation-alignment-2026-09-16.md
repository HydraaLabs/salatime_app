# Alignement des calculs Moatheni — 16 septembre 2026

**Suites après cet audit :** [fenêtre Android de trois jours et vérification Samsung](prayer-three-day-window-2026-09-16.md), puis [sélection automatique par pays et Isha pendant Ramadan](prayer-country-ramadan-2026-09-16.md). Ces suites remplacent les constats ci-dessous concernant l'absence de rotation de la réserve et les options qui n'étaient pas encore implémentées lors de la première tranche.

Les **11 méthodes communes** sont alignées dans le calculateur local SalaTime. Les observations ci-dessous proviennent d'une analyse statique de Moatheni **3.0.5 (63)**, paquet `com.mahmoud.android.Adani`, et du code SalaTime. Une comparaison indépendante vérifie 1 232 cas du moteur public Adhan Kotlin ; elle ne constitue pas un essai de l'application Moatheni sur téléphone.

[Fiche Play de référence](https://play.google.com/store/apps/details?id=com.mahmoud.android.Adani). APK : `/home/hemiad/Downloads/SalaTime-reference/Moatheni.apk`, SHA-256 `24ab1a89bede8d9a31ac77a105e94349bf76c3318b356a477f7d0dd7637169f4`.

## Méthodes et identifiants

Les identifiants persistés SalaTime suivent Aladhan ; les ordinaux internes Moatheni sont différents. Les angles sont déjà concordants avant cette tranche. Les écarts concernent surtout les corrections internes et l'arrondi.

| Méthode | Ordinal moteur Moatheni | ID SalaTime | Fajr | Isha | Corrections internes, en minutes |
|---|---:|---:|---:|---|---|
| Muslim World League | 0 | 3 | 18° | 17° | Dohr +1 |
| Egyptian | 1 | 5 | 19,5° | 17,5° | Dohr +1 |
| Karachi | 2 | 1 | 18° | 18° | Dohr +1 |
| Umm Al-Qura | 3 | 4 | 18,5° | Coucher +90 min | Aucune |
| Dubai | 4 | 16 | 18,2° | 18,2° | Lever −3 ; Dohr/Asr/Maghrib +3 |
| Moonsighting Committee | 5 | 15 | 18° et bornes saisonnières | 18° et bornes saisonnières | Dohr +5 ; Maghrib +3 |
| North America / ISNA | 6 | 2 | 15° | 15° | Dohr +1 |
| Kuwait | 7 | 9 | 18° | 17,5° | Aucune |
| Qatar | 8 | 10 | 18° | Coucher +90 min | Aucune |
| Singapore | 9 | 11 | 20° | 18° | Dohr +1 ; arrondi supérieur |
| Turkey | 10 | 13 | 18° | 17° | Lever −7 ; Dohr +5 ; Asr +4 ; Maghrib +7 |

Les sources de référence sont sous `/tmp/salatime-moatheni-audit/jadx/sources/` :

- `com/batoulapps/adhan2/CalculationMethod.java:11-22` : ordinaux ; `:108-133` : coefficients et corrections. `OTHER`, ordinal 11, n'est pas proposé dans la liste utilisateur.
- `com/mahmoud/android/Adani/util/PrayerManager.java:35-38` : utilisation directe du preset choisi.
- [Source publique du moteur Adhan : CalculationMethod](https://github.com/batoulapps/adhan-kotlin/blob/main/adhan/src/commonMain/kotlin/com/batoulapps/adhan2/CalculationMethod.kt).
- [Documentation Aladhan sur les méthodes et corrections](https://aladhan.com/calculation-methods). Un même nom de convention ne dispense pas de comparer ses corrections ; modifier Maghrib ne décale pas automatiquement Isha dans l'API Aladhan.

## Latitude, école et arrondi

Moatheni garde les valeurs par défaut du moteur : école **SHAFI**, arrondi **au plus proche**, Shafaq **GENERAL**. Singapore demande un arrondi **au supérieur**. Les corrections internes sont ajoutées avant l'arrondi (`CalculationParameters.java:157-158`, `CalculationMethod.java:129`, `PrayerTimes.java:205-210`, `data/CalendarUtil.java:46-64`, sous `com/batoulapps/adhan2/`).

Sa règle de haute latitude est sélectionnée par le moteur : **latitude >48° nord → septième de nuit ; sinon milieu de nuit**. La comparaison porte sur la latitude signée. Moonsighting possède aussi son traitement saisonnier et une règle particulière à partir de 55° nord (`HighLatitudeRule.java:54-59`, `CalculationParameters.java:252-267`, `PrayerTimes.java:154-188`).

SalaTime utilisait auparavant `twilight_angle` pour toutes les méthodes. Changer cette règle modifie réellement Fajr/Isha en haute latitude : pour une nuit de huit heures, une borne de 1/7 représente environ 69 minutes, contre 144 minutes pour un angle de 18° divisé par 60. Ce sont les bornes théoriques, pas des horaires mesurés ; la comparaison saisonnière doit couvrir notamment Paris et Stockholm. Un alignement de ces règles ne peut pas être présenté comme une simple correction d'une minute.

Le choix utilisateur **STANDARD/HANAFI reste conservé**. La référence ne montre pas de personnalisation Madhab dans les réglages inspectés, mais cela ne justifie pas de retirer Hanafi de SalaTime.

La dépendance Dart Adhan 2.0.0+1 dispose des presets et corrections de méthode, mais n'exposait pas d'arrondi supérieur. Elle est désormais conservée sous `third_party/adhan`, avec sa licence MIT et une adaptation minimale ajoutant cet arrondi sur les instants bruts avant formatage. Les autres méthodes gardent l'arrondi au plus proche. Aucun code propriétaire Moatheni n'est intégré.

Exemples calculés avant/après, école STANDARD et aucune correction personnelle :

| Ville, méthode, date locale | Avant | Après |
|---|---|---|
| Dubaï, Dubai, 16/09/2026 | Lever 06:05 ; Dohr 12:14 ; Asr 15:41 ; Maghrib 18:22 | 06:02 ; 12:17 ; 15:44 ; 18:25 |
| Istanbul, Turkey, 16/09/2026 | Lever 06:45 ; Dohr 12:59 ; Asr 16:29 ; Maghrib 19:12 | 06:38 ; 13:04 ; 16:33 ; 19:19 |
| Paris, MWL, 21/06/2026 | Fajr 03:26 ; Isha 00:11 | Fajr 04:40 ; Isha 23:05 |
| Casablanca, Maroc, 16/09/2026 | Fajr 05:46 ; Dohr 13:25 ; Isha 20:54 | Identiques |

L'écart est donc important pour les méthodes communes en été au nord de 48° ; il résulte de la convention de nuit de la référence. Les méthodes régionales supplémentaires et les réglages personnels restent disponibles.

## Sélection automatique et Ramadan dans la référence

Moatheni active par défaut la sélection automatique selon le pays (`com/mahmoud/android/Adani/util/PrayerManager.java:111-180`) :

| Pays | Méthode automatique |
|---|---|
| AE | Dubai |
| EG | Egyptian |
| KW | Kuwait |
| LY, SA | Umm Al-Qura |
| PK | Karachi |
| QA | Qatar |
| SG | Singapore |
| TR | Turkey |
| CA, MX, US | ISNA |
| Autres pays, dont MA et FR | Moonsighting Committee |

Cette sélection géographique n'est pas reprise dans cette tranche : SalaTime conserve son identifiant par défaut existant et les choix déjà enregistrés.

Le réglage nommé « Isha pendant Ramadan » dans Moatheni est un remplacement manuel : 0 = horaire calculé, 1 = Maghrib ajusté +90 minutes, 2 = Maghrib ajusté +120 minutes. `PrayerManager.java:435-447` l'applique après les corrections personnelles, **sans condition de mois dans ce chemin**. L'interface le stocke dans `ishaTimeInRamadan` (`settings/EditPrayerTimesActivity.java:43-51`, `:90-101`). Ce constat ne prouve pas une bascule automatique de Ramadan. [Le moteur Adhan documente séparément un ajustement de +30 minutes pour Umm Al-Qura pendant Ramadan](https://github.com/batoulapps/adhan-kotlin).

## Incohérence de liste dans Moatheni : inférence statique

La liste affichée place Qatar, Kuwait, Moonsighting, Singapore et ISNA aux indices 5 à 9 ; le moteur place respectivement Moonsighting, ISNA, Kuwait, Qatar et Singapore à ces indices. Le sélecteur enregistre directement la position, puis le calculateur lit directement l'ordinal.

Preuves : `com/mahmoud/android/Adani/settings/PrayerTimesSettingsActivity.java:103-126`, `settings/GeneralSelectionActivity.java:106-123`, `util/PrayerManager.java:113`, et enum cité plus haut. Cela suggère un mauvais appariement de certains choix manuels dans cette version. Ce problème **n'a pas été reproduit sur appareil** et ne doit pas être copié : SalaTime garde un mapping explicite par ID stable.

## Périmètre de l'implémentation

- Les 11 presets communs de `lib/helper/local_prayer_calculator.dart` utilisent les paramètres nommés, corrections, règle de latitude et arrondi vérifiés.
- Conserver les **12 méthodes supplémentaires** : IDs `0, 7, 8, 12, 14, 17, 18, 19, 20, 21, 22, 23`, y compris Maroc, France, Algérie, Tunisie, Portugal et Jordanie.
- Conserver les identifiants de `lib/helper/prayer_calculation_methods.dart`, le défaut existant, les préférences persistées, l'école Hanafi et les corrections personnelles.
- Le calcul automatique par coordonnées est **local** : `lib/controller/package_prayer_time_controller.dart:528-529` retourne directement `LocalPrayerCalculator.calculate`. Le chemin calendrier manuel conserve son traitement distinct. Aucun changement du backend n'est prévu.
- Aucun changement de design, nouvel asset ou publication dans cette tranche. Les nouveaux calculs doivent alimenter la reprogrammation existante ; aucune publication ne peut être déduite de tests locaux.

## Réveils et priorité des notifications

La référence emploie `setAlarmClock` pour toutes ses alertes activées, `PRIORITY_MAX` (2) pour l'alerte active et `IMPORTANCE_HIGH` (4) pour son canal. Sa notification permanente utilise un canal `LOW` (2). Preuves : `util/NotificationManager.java:226`, `util/NotificationReceiver.java:94,156,168`.

- SalaTime utilise maintenant `setAlarmClock` pour les phases avant/adhan/après **et les rappels supplémentaires activés**, avec repli `setAndAllowWhileIdle` si l'autorisation exacte manque. Les rappels désactivés restent absents du plan, les identifiants/annulations et le plafond partagé de 450 restent conservés.
- Android affiche donc comme prochain réveil la prochaine alerte activée, éventuellement un rappel supplémentaire. Ces réveils peuvent sortir le téléphone de Doze ; c'est le compromis de précision de la référence, avec un coût énergétique possible. Le raccourci ouvre SalaTime et ne déclenche jamais le receiver.
- Les nouveaux canaux utilisent explicitement `HIGH` (4), et la priorité avant Android 8 reste `MAX` (2). `IMPORTANCE_MAX` (5) était réservé au système et ne constituait pas une priorité d'application supérieure utile. [Référence Android](https://developer.android.com/reference/android/app/NotificationManager#IMPORTANCE_MAX).
- Pour l'adhan lu par le service, Android 8+ possède un canal de lecture `HIGH` sans son système, badge ni vibration par défaut. Le lecteur natif reste l'unique source sonore. Cela retire le mode `setSilent(true)` du cas normal, qui pouvait supprimer la présentation en bandeau malgré la priorité élevée. [Contrat `setSilent`](https://developer.android.com/reference/androidx/core/app/NotificationCompat.Builder#setSilent(boolean)).
- Le canal source reste autoritaire : son coupé, canal bloqué ou importance abaissée ne sont pas contournés. Les changements de l'utilisateur sur le canal de lecture restent conservés. Si un son y est ajouté manuellement, le mode silencieux de notification évite une seconde lecture simultanée.
- Chaque nouvel adhan est une nouvelle alerte (`onlyAlertOnce=false`), tandis que les mises à jour du décompte restent silencieuses sur le canal `LOW`. Les commandes du service demandent un affichage immédiat. Leur visibilité réelle dépend de SystemUI, des réglages de l'appareil et de ses restrictions.

Ces modifications prolongent l'[audit précédent](moatheni-notifications-audit-2026-09-16.md), où seuls les trois temps de prière utilisaient le réveil. Elles ne créent pas un renouvellement autonome illimité.

## Renouvellement des alertes : constat et proposition séparée

Moatheni calcule trois jours et les renouvelle après chaque notification (`util/NotificationManager.java:20-34`, `util/NotificationReceiver.java:97`). SalaTime calcule jusqu'à 30 jours, plus la veille pour les chevauchements, et partage un plafond de 450 alarmes Android (`lib/helper/salat_waqt_service.dart:208-215`, `:370-399`). Selon les rappels activés, la couverture armée peut être inférieure à 30 jours. Le receiver natif consomme une occurrence sans reconstruire la fenêtre.

Proposition bornée, **non implémentée dans cette tranche** :

1. Extraire un renouvellement passif indépendant des écrans et contrôleurs GetX, alimenté par un instantané persistant : lieu, fuseau, méthode, école, corrections et notifications activées. Réutiliser le même calculateur Dart pour éviter deux moteurs divergents.
2. Ajouter un travail périodique Android unique, par exemple quotidien, et une demande unique de rattrapage quand une réception constate moins de sept jours de couverture. Calculer au maximum 30 jours, conserver le budget partagé et n'afficher aucune demande de permission depuis l'arrière-plan.
3. Sérialiser les écritures entre application et travail de fond avec une révision persistée. Conserver les alarmes valides en cas d'échec et reprendre les opérations partielles. Le coordinateur Dart actuel n'est qu'un verrou dans son isolate et ne suffit pas entre deux moteurs Flutter.
4. Pour les calendriers manuels sans journées disponibles, préserver les occurrences connues et signaler la couverture réelle ; ne pas inventer les horaires ni répéter ceux du jour à +24 heures.
5. Garder AlarmManager responsable du déclenchement exact ; WorkManager ne sert qu'à prolonger la réserve. Vérifier redémarrage, mise à jour, changement de paramètres en cours de travail, expiration de fenêtre, Doze et reprise après arrêt forcé sur appareil.

Le travail périodique peut être différé par Android : la réserve sert à absorber ce délai, pas à promettre un renouvellement à une heure précise. [PeriodicWorkRequest](https://developer.android.com/reference/androidx/work/PeriodicWorkRequest), [travaux uniques](https://developer.android.com/develop/background-work/background-tasks/persistent/how-to/manage-work). Cette proposition nécessite un point d'entrée Flutter de fond et une coordination persistante absents du chemin inspecté ; elle ne se réduit pas à appeler la reprogrammation depuis le receiver.

## Validation

- **1 232 cas indépendants / 7 392 horaires identiques à la minute affichée**, générés par Adhan Kotlin JVM 0.0.5 : 11 méthodes, 2 écoles, 8 lieux, 7 dates avec saisons et changements d'heure. Les attendus ne sont pas générés par SalaTime. Générateur, versions/empreintes et commande de reproduction : `tool/adhan_reference/README.md` ; fixture `test/fixtures/adhan_kotlin_0_0_5.csv` ; test `test/helper/adhan_reference_alignment_test.dart`.
- **384 cas historiques** pour les 12 autres méthodes : mêmes attendus PHP et même tolérance de deux minutes que précédemment ; aucun assouplissement pour masquer les changements.
- Suite Flutter complète : **555 tests réussis**. L'arrondi brut, les seuils de latitude, Hanafi, les identifiants, la sélection, la persistance, les corrections et la planification sont couverts.
- Analyse Flutter complète : **aucun problème**. Licence de la dépendance conservée ; `git diff --check` sans erreur.
- Tests Android : **183 tests réussis**, aucune erreur ni échec, couvrant les alarmes, la restauration, les contrôles audio, les permissions et les canaux de priorité. Les deux anciennes attentes des rappels supplémentaires ont été adaptées à leur changement explicite de mode vers `alarmClock`.
- APK local construit et signature vérifiée : `build/reference-audit/SalaTime-test-calculs-reveils-2026-09-16.apk`, **212 837 900 octets**, SHA-256 `070aec71ff9e9447d059e638700323270ef41431e49e0010cbd56159e9c6c2b1`. Paquet relu : **SalaTime Test**, `net.salatime.app.preview`, `1.0.21+24`, cible Android 36 ; compilation debug demandée pour ARM64. Le nouveau canal de lecture et l'adaptateur d'alarmes sont présents dans le DEX. Le paquet de test reste distinct de Play et contient l'état local du dépôt, y compris les modifications déjà présentes avant cette tranche.
- Journaux : `/tmp/salatime-calculation-oracle.log`, `/tmp/salatime-alignment-flutter-final.log`, `/tmp/salatime-alignment-native-final.log`, `/tmp/salatime-alignment-analyze-final.log`, `/tmp/salatime-alignment-apk-build.log`.
- Aucun appareil dans `adb devices -l` pendant cette tranche. Le bandeau réel et la réception en veille Samsung restent à vérifier ; aucun push, déploiement ou envoi Play/Shorebird.
- La sélection automatique par pays, la gestion du fuseau d'une ville distante et le renouvellement de réserve sans réouverture restent distincts de cet alignement. Aucune bascule Ramadan automatique n'a été ajoutée : elle n'est pas démontrée dans le chemin de référence étudié.
