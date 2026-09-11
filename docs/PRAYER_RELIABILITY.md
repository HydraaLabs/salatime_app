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
- Android : alarmes exactes autorisées pendant la veille, ou repli non exact si
  l’autorisation manque. L’utilisateur voit ce mode dégradé dans les alarmes.
- Ignorer une prière concerne sa date et ses rappels, avec possibilité de rétablir.
- Au redémarrage Android, suppression des occurrences dépassées avant
  restauration, avec un seul avis silencieux de prière manquée. Pas de badge.
- Aucun système ne peut garantir une alarme après un arrêt forcé de l’app par
  l’utilisateur ou certains blocages constructeur. Ces cas nécessitent des essais
  sur appareil ; les tests unitaires ne constituent pas une validation matérielle.

`SalaTimeAlarmRestoreReceiver` est un adaptateur du stockage interne de
`flutter_local_notifications` **17.2.4**, version verrouillée dans pubspec.yaml.
Réexaminer l’adaptateur et ses tests avant toute mise à jour de ce paquet.
Il préserve les notifications étrangères à SalaTime et ne fait appel à aucun
service réseau lors du redémarrage.

## Widget et carte

Le widget Android affiche la prochaine prière, sa date, son heure et la ville.
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
- https://github.com/meypod/al-azan-compose : idées de fiabilité et d’interface ; aucun code AGPL repris.
- https://github.com/TowardsIkhlaas/simply_qibla : idée de repérage sur carte ; aucun code GPL repris.
- https://github.com/iamriajul/adhan-dart : dépendance MIT, déclarée dans pubspec et les licences Flutter.

Validation du 11 septembre 2026 : 68 tests Flutter réussis, 10 tests Android
Robolectric réussis (restauration, badges et widget), analyse Flutter sans
problème et APK debug compilé. Écran des alarmes contrôlé à 360 × 800 avec
texte agrandi en français. Aucun appareil/émulateur connecté ; pas de validation
sur téléphone ni de publication Google Play/Shorebird dans cette modification.
