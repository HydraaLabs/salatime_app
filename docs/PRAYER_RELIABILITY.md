# Horaires et alarmes de SalaTime

Les horaires automatiques sont calculés sur l’appareil avec `adhan` 2.0.0+1 (MIT).
Les 23 méthodes de l’interface ont des paramètres explicites. Les calendriers
manuels sans coordonnées conservent le calendrier serveur et son cache.
Les résultats automatiques ignorent l’ancien cache serveur : le moteur PHP du
checkout attend des noms de méthode, alors que l’API transmet des identifiants.
La conversion de chaque instant utilise la base IANA incluse dans `timezone`,
sans reprendre l’offset à minuit du serveur. Les calculs restent des horaires
astronomiques ; les ajustements enregistrés par l’utilisateur s’appliquent aux alarmes.

## Programmation

- Fenêtre de 30 jours, dates calculées individuellement, identifiants stables.
- Android : au maximum 450 requêtes, rappels inclus ; iOS : au maximum 60,
  en laissant une marge sous la limite de 64. Les autres notifications sont décomptées.
- iOS peut donc ne couvrir qu’environ quatre jours avec tous les rappels actifs.
  L’écran des alarmes affiche la dernière occurrence programmée. Il faut rouvrir
  l’app avant la fin de cette fenêtre pour la prolonger.
- Actualisation à l’ouverture, à la reprise, à minuit pendant l’utilisation,
  lors des changements de lieu et de réglages. Les actualisations sont sérialisées.
- Android : l’adhan principal utilise `setAlarmClock`, avec un raccourci système
  qui ouvre SalaTime. Les rappels utilisent `setExactAndAllowWhileIdle` ; ils
  restent soumis aux quotas de veille d’Android. Sans autorisation d’alarme
  exacte, le repli est non exact et l’écran des alarmes indique cette limitation.
- Ignorer une prière concerne sa date et ses rappels, avec possibilité de rétablir.
- Au redémarrage Android, suppression des occurrences dépassées avant
  restauration, avec un seul avis silencieux de prière manquée. Pas de badge.
- Lors d’une livraison retardée de plus de deux minutes, l’adhan apparaît
  silencieusement avec son heure prévue. Les rappels dépassés sont supprimés,
  notamment un rappel « avant l’adhan » reçu après l’heure de la prière.
- Les sons `azan_1`, `azan_2` et `azan_3` sont lus intégralement par un service
  Android temporaire avec le volume des alarmes et un bouton « Arrêter ».
  Il respecte les notifications/canaux désactivés, le volume nul et la priorité
  audio des appels. Fin, arrêt, erreur et perte de priorité libèrent le lecteur,
  la priorité audio et le verrou de veille ; durée maximale de huit minutes.
- Aucun système ne peut garantir une alarme après un arrêt forcé de l’app par
  l’utilisateur ou certains blocages constructeur. Ces cas nécessitent des essais
  sur appareil ; les tests unitaires ne constituent pas une validation matérielle.

`SalaTimePrayerAlarms`, `SalaTimePrayerAlarmReceiver`, `SalaTimeAdhanService`
et `SalaTimeAlarmRestoreReceiver` sont des adaptateurs du stockage interne de
`flutter_local_notifications` **17.2.4**, version verrouillée dans pubspec.yaml.
Réexaminer les adaptateurs et leurs tests avant toute mise à jour de ce paquet.
Le cache du paquet reste la source des alarmes en attente. Une livraison dont
l’identifiant ou l’heure ne correspond plus au cache est ignorée. L’adaptateur
préserve les notifications étrangères à SalaTime et ne fait appel à aucun
service réseau lors du redémarrage.
Chaque alarme est transférée immédiatement après sa programmation : le
renouvellement des 450 alarmes ne crée pas une deuxième copie du calendrier
entier, susceptible de dépasser la limite signalée sur Samsung.

## Vérification sur téléphone

Dans les réglages des notifications, ouvrir **Alarmes à venir**, puis
**Tester dans une minute**. Verrouiller le téléphone et attendre sans rouvrir
SalaTime. Le test emprunte le même parcours de programmation et de lecture
que les prières, avec le son choisi. Il peut être annulé avant le déclenchement.
Le test bref vérifie le fonctionnement écran verrouillé ; il ne remplace pas
un essai après plusieurs heures de veille. L’écran affiche les autorisations,
le volume des alarmes et le retard mesuré de la dernière livraison.

Sur Samsung, vérifier aussi les réglages des applications en veille/profonde
et la liste des applications jamais en veille. Le fonctionnement après un arrêt
forcé, une restriction constructeur ou en veille prolongée nécessite une
vérification sur l’appareil concerné.

Cette correction comporte du code Android natif : une nouvelle installation
APK/AAB est nécessaire. Un patch Dart Shorebird seul ne la distribue pas.

## Widget et carte

Le widget Android affiche la prochaine prière, sa date, son heure et la ville.
Son format initial horizontal (4 × 1 cases) utilise un fond ivoire, une heure
en grand, des accents verts et la même illustration de mosquée que l'accueil
de l'application, intégrée en fond à transparence réduite.
À partir de 240 × 180 dp, il ajoute les cinq
horaires de la journée de la prochaine prière et met celle-ci en évidence.
Le redimensionnement adapte la présentation, y compris sur les versions Android
antérieures à Android 12. La langue, le fuseau et le format 12/24 h sont transmis
par l'application ; l'affichage arabe suit le sens de lecture de droite à gauche.
Il fonctionne sur les 30 jours de données préparées même si les alarmes sont
désactivées. Son rafraîchissement est non exact et peut être retardé en veille.
Toucher le widget ouvre SalaTime. Aucun widget iOS n’est ajouté par cette version.

La carte Qibla permet de toucher une position sans utiliser les capteurs ni GPS.
Le nord reste en haut ; un segment local suit le relèvement initial vers la Kaaba.
Les tuiles OpenStreetMap nécessitent une connexion et portent leur attribution.

## Vérification et références

`test/fixtures/prayer_times_reference.json` contient 736 journées : 23 méthodes,
deux écoles, quatre villes et quatre dates 2026. Les valeurs numériques UTC ont
été produites par le moteur du checkout web en lui passant les **noms** de
méthode et un fuseau UTC fixe, pour isoler la comparaison astronomique des défauts
 d’identifiant et de la base de fuseaux du serveur. Les comparaisons acceptent
2 minutes de différence entre les algorithmes. Moonsighting utilise les bornes
saisonnières et corrections du moteur Adhan et peut différer de 8 minutes du moteur
PHP ancien ; cette différence est explicitement testée. Des tests séparés couvrent
les changements d’heure, le Ramadan au Maroc, les autorisations, les dates et les limites iOS.

Références étudiées :
- https://developer.android.com/develop/background-work/services/alarms
- https://developer.android.com/training/monitoring-device-state/doze-standby
- https://www.samsung.com/ca/support/mobile-devices/galaxy-phone-sleeping-apps/
- https://github.com/meypod/al-azan-compose : idées de fiabilité et d’interface ; aucun code AGPL repris.
- https://github.com/TowardsIkhlaas/simply_qibla : idée de repérage sur carte ; aucun code GPL repris.
- https://github.com/iamriajul/adhan-dart : dépendance MIT, déclarée dans pubspec et les licences Flutter.

Validation du 11 septembre 2026 : 68 tests Flutter réussis, 10 tests Android
Robolectric réussis (restauration, badges et widget), analyse Flutter sans
problème et APK debug compilé. Écran des alarmes contrôlé à 360 × 800 avec
texte agrandi en français. Aucun appareil/émulateur connecté ; pas de validation
sur téléphone ni de publication Google Play/Shorebird dans cette modification.

Validation de la correction de veille du 12 septembre 2026 : 79 tests Flutter
réussis et 36 tests Android Robolectric réussis. Les cas couvrent la livraison
retardée de 26 minutes, l’absence de rappels périmés, la lecture et l’arrêt de
l’adhan, le volume nul, le refus de priorité audio, l’annulation, les doublons
et le renouvellement de 450 alarmes sous une limite simulée de 500.
Le test dans l’interface a été contrôlé en français à 360 × 800 et texte × 1,5.
Aucun appareil Android connecté : le déclenchement sur le Samsung de
l’utilisateur, notamment après une nuit de veille, reste à vérifier.
