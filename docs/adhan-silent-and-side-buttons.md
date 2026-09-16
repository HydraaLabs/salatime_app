# Adhan : mode silencieux et boutons latéraux

## Correction

La lecture native utilisait `USAGE_ALARM` et contrôlait le volume des alarmes
ainsi que le mode d'appel, mais ne consultait pas `getRingerMode()`. Une alarme
audible pouvait donc démarrer avec le téléphone en silencieux ou vibreur.

Le mode silencieux/vibreur, les appels et un volume d'alarme nul bloquent
maintenant l'audio. La vérification a lieu dans le récepteur, au lancement du
service et après la préparation asynchrone du fichier. Pendant la lecture,
une bascule en silencieux/vibreur arrête aussi l'adhan. L'avis de prière reste
visible, silencieux et sans badge. Le retour au mode normal ne rejoue rien.

Si le service de lecture ne peut pas démarrer, l'avis reste silencieux : aucun
long son de canal Android incontrôlable n'est lancé en remplacement.

## Arrêt

### Compteur dans la notification Android

La notification d'adhan affiche la date hégirienne corrigée selon les paramètres,
le nom de la prière, son heure au format choisi et un chronomètre vert du temps
écoulé depuis l'heure programmée de la prière pendant une heure. Ensuite elle
montre le nom et l'heure de la prochaine prière, avec son décompte. Celui-ci
passe au rouge lorsqu'il reste une heure ou moins, seuil inclus. La première
heure après l'adhan reste verte ; si la prière suivante survient plus tôt, elle
remplace directement la précédente. Le calcul inclut les prières dont le son
est désactivé, exclut le lever du soleil et passe d'Icha au Fajr du lendemain.

Le compteur continue après la fin ou l'arrêt de l'audio et lorsque le téléphone
est silencieux. L'action « Arrêter » reste présente uniquement pendant la lecture.

`SalaTimeAdhanNotification` utilise une vue de notification décorée et un
`Chronometer` animé par SystemUI. Un seul rendez-vous natif à la fois gère les
changements de présentation : fin de la première heure, seuil rouge, puis retrait
à l'heure de la prochaine prière. Aucun service ni rafraîchissement par seconde
n'est ajouté. Les transitions sont silencieuses, sans vibration, et ne relancent
jamais l'audio. Une notification effacée par l'utilisateur n'est pas recréée.
L'état est conservé sur disque ; la restauration vérifie d'abord les notifications
encore présentes. Une nouvelle notification d'adhan remplace la précédente.

Les transitions utilisent l'autorisation d'alarmes exacte existante, avec repli
inexact si elle est indisponible ; Android peut alors différer une bascule.
Les couleurs s'adaptent aux thèmes clair et sombre, la disposition à la langue,
et le badge reste désactivé. Les rappels
avant/après et les notifications de test conservent leur présentation standard.
Les notifications déjà programmées reçoivent les métadonnées au prochain
recalcul des alarmes ; les anciennes charges utiles restent compatibles.

Cette présentation repose sur du code Android natif et nécessite une nouvelle
compilation de l'application. Le rendu One UI reste à vérifier sur Samsung.

Validation locale du 15 septembre 2026 : 15 tests Flutter du planificateur,
122 tests Robolectric (API 24/33 : transitions aux seuils, décompte, effacement,
restauration, affichage, langue arabe, thème sombre, mode silencieux, contrôles
audio et alarmes) réussis ; analyse
Dart ciblée sans erreur. Aucun appareil ADB connecté pendant cette validation.

### Priorité après la lecture

Pendant l'audio, la notification reste sur le canal d'adhan prioritaire avec
l'action « Arrêter ». Dès la fin, l'arrêt ou la suppression du son, le suivi
utilise `prayer_tracking_no_badge_v1` (« Suivi des prières ») : importance LOW,
catégorie STATUS, sans son, vibration, badge ou maintien au premier plan. Les
mises à jour du compteur gardent ce canal, y compris au passage en rouge.
Android 7 utilise également la priorité LOW. La création du canal de suivi ne
modifie pas les canaux d'adhan et ne contourne pas leur désactivation par
l'utilisateur. L'ordre final reste décidé par Android/One UI et ses réglages.

Validation du correctif : 128 tests Android natifs réussis (API 24/33),
avec vérification du canal et de la priorité après arrêt, pendant les transitions,
et du respect des canaux désactivés. Samsung non connecté pendant ces tests.

### Une seule notification conservée

Le suivi et la lecture de l'adhan partagent maintenant l'identifiant d'affichage
9901. Les identifiants des occurrences programmées, leurs actions et leurs données
restent distincts : remplacer une carte ne supprime aucune alarme à venir.
Les transitions de compteur mettent à jour cette même carte ; publication et
état sauvegardé sont protégés contre une mise à jour concurrente en arrière-plan.

Avant/après l'adhan et autres rappels utilisent une seule carte temporaire (9902),
qui remplace le rappel précédent. Sa durée est de 60 secondes, raccourcie à
l'heure de la prière pour un rappel « avant ». Android 8+ reçoit une expiration
système ; une alarme native assure aussi le retrait sur Android 7 et restaure
le délai après recréation du processus. Les restrictions d'alarmes Android
peuvent retarder ce repli. L'arrivée de l'adhan retire le rappel immédiatement.
Les sons configurés et les futures programmations sont conservés.

À la publication d'une alerte et au rétablissement des alarmes (lancement,
reprise ou mise à jour), les anciennes cartes de prière/rappel sont retirées
selon leurs identifiants et canaux connus. Les notifications d'autres fonctions
et les services audio en cours restent protégés. Si un compteur d'une version
précédente est encore affiché avec son état sauvegardé, il est repris sous 9901.
Les notifications effacées volontairement ne sont pas recréées.

Validation du 16 septembre 2026 : 140 tests Android réussis (API 24/33),
dont répétition des prières, remplacement/expiration des rappels, ancienne pile,
conservation des futures alarmes et reprise du compteur existant. Pas de Samsung
connecté pendant cette validation.

### Commandes pendant la lecture

- SalaTime visible : Volume +, Volume − ou Muet arrête l'adhan actif, y compris
  aux limites du volume. Les répétitions et le relâchement sont consommés ;
  les autres sons/touches conservent leur fonctionnement hors lecture d'adhan.
- Arrière-plan ou appareil verrouillé : la lecture surveille les changements
  des volumes alarme/média/sonnerie/notification toutes les 250 ms et s'arrête
  à une variation. Le service ne modifie aucun volume système.
- Une nouvelle mise en veille ou un nouveau réveil de l'écran arrête l'adhan.
  Le démarrage lorsque l'écran est déjà éteint reste possible en mode sonore.
- Le bouton « Arrêter » de la notification reste disponible.

Android consomme la touche alimentation ; l'application reçoit les transitions
`SCREEN_OFF`/`SCREEN_ON`, qui peuvent aussi venir d'un délai de veille, d'un
double appui sur l'écran ou d'une autre cause de réveil. Hors de l'activité,
un appui de volume qui ne change pas la valeur (par exemple Volume + déjà au
maximum) n'est pas détectable par ces API publiques. L'autre sens, la transition
d'écran et l'action de notification permettent l'arrêt. Aucune permission
d'accessibilité, écoute globale des touches ou fausse route audio distante.

La surveillance existe uniquement pendant la préparation/lecture, bornée par
la durée maximale de huit minutes. Tous les chemins de sortie libèrent lecteur,
priorité audio, récepteurs, temporisateurs et verrou de veille ; aucune reprise
automatique après un arrêt utilisateur.

## Sources Android

- [Mode de sonnerie](https://developer.android.com/reference/android/media/AudioManager#getRingerMode())
- [Volume des flux audio](https://developer.android.com/reference/android/media/AudioManager#getStreamVolume(int))
- [Mise en veille](https://developer.android.com/reference/android/content/Intent#ACTION_SCREEN_OFF)
- [Réveil](https://developer.android.com/reference/android/content/Intent#ACTION_SCREEN_ON)

## Essai sur Samsung

Utiliser SalaTime Test, **Paramètres → Notifications → Alarmes à venir →
Tester dans une minute**, sans modifier les horaires réels. Vérifier les modes
silencieux et vibreur avec volume d'alarme non nul ; aucun son ne doit sortir.
En mode sonore, tester séparément Volume +, Volume −, l'extinction puis le
réveil de l'écran, et l'action « Arrêter » de la notification. Tester aussi une
bascule en silencieux pendant l'adhan. Restaurer les réglages audio initiaux
après l'essai. La version Play et la prévisualisation sont deux installations
distinctes : identifier la notification de SalaTime Test pendant l'essai.

Les changements sont natifs Android et nécessitent un nouvel APK/AAB. Un
patch Dart Shorebird seul ne peut pas les distribuer. Aucune publication n'est
incluse dans cette correction.

## Validation du 13 septembre 2026

- 152 tests Android réussis (dont 63 nouveaux cas : silence/commandes SDK24
  et33, ainsi que 7 cas de séquences de touches).
- 9 tests Flutter ciblés réussis (diagnostic, silence automatique, audio).
- Analyse globale Flutter sans anomalie ; git diff --check propre.
- APK debug signé : `/home/hemiad/Downloads/SalaTime-test-silencieux-boutons-1.0.16-19.apk` ; paquet `net.salatime.app.preview` ;
  version 1.0.16+19.
- Taille : 201644150 octets. SHA-256 :
  `8de8533977fdaa4c13551f75fd0f1de9cc4cb1643b996492c3c1d5d7ec22f08f`. Les nouvelles classes/commandes natives sont présentes.
- Samsung absent d'ADB lors de la validation : APK préparé, pas installé et
  comportement physique non vérifié. Aucune publication Git/Play/Shorebird.
