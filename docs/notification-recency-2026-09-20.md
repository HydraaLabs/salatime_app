# Remontée de la notification Android — 20 septembre 2026

Chaque prière activée conserve son adhan, même si la notification précédente
est encore dans le volet. Le service audio présente chaque nouvel adhan comme
une nouvelle alerte ; la carte utilise toujours le même identifiant pour éviter
les doublons. Les mises à jour du compte à rebours restent silencieuses.

## Correction

Une actualisation de la carte existante conservait l'heure du dernier adhan.
Le receiver utilise maintenant l'heure de l'actualisation pour son classement,
sans modifier l'instant de prière utilisé par le chronomètre. Sur le Samsung
de test, changer cet horodatage seul ne changeait pas l'ordre des cartes.
La carte silencieuse est donc retirée puis réaffichée avec le même identifiant
pour renouveler aussi sa date de création.

Le contrôle de présence est conservé : une carte effacée par l'utilisateur
n'est pas réaffichée. Une lecture d'adhan en cours et son bouton d'arrêt ne
sont pas remplacés. Les canaux désactivés et les alarmes arrivées en retard
gardent leurs protections. Aucun rafraîchissement périodique supplémentaire
n'a été ajouté : seules les actualisations déjà prévues utilisent ce traitement.

## Validation

- 203 tests natifs réussis sur les parcours de notifications, dont deux adhans
  successifs avec une carte conservée entre les deux : le second lecteur démarre,
  la notification redevient une alerte et une seule carte de prière reste présente.
- Les transitions du compte à rebours actualisent leur horodatage, conservent
  la durée correcte et ne déclenchent ni son ni vibration.
- Sur le Samsung SM-S901U / Android 12, deux cartes QA de même priorité ont été
  créées dans une installation `.preview` séparée. La carte de prière se trouvait
  après le repère dans la liste du système (indices 8 et 7). Après actualisation,
  la carte de prière passe à l'indice 7 et le repère à l'indice 8. Sa nouvelle date
  de classement est confirmée par Android. Il s'agit d'un contrôle du classement
  système ; aucune capture du volet personnel n'est conservée.

Android et le constructeur gardent la maîtrise du classement entre niveaux
d'importance. Cette correction ne force pas une carte de suivi silencieuse
devant un appel ou une alerte plus importante. Voir la
[documentation Android sur la mise à jour des notifications](https://developer.android.com/develop/ui/compose/notifications/create-notification#Updating)
et le [calcul de l'horodatage de classement dans Android](https://github.com/aosp-mirror/platform_frameworks_base/blob/main/services/core/java/com/android/server/notification/NotificationRecord.java).

Les preuves et le helper temporaire sont archivés dans
`release-artifacts/notification-recency-2026-09-20/`. Le build de vérification est
un APK debug de la copie `.preview`, sans télémétrie. Les copies de test sont
retirées après validation ; l'application Play du téléphone reste en 1.0.22+25.
Les réglages de volume et les autres réglages du téléphone n'ont pas été modifiés.

La correction a ensuite été poussée et intégrée à la release Android 1.0.24 (27).
La création de la nouvelle base Shorebird et l'envoi à Google Play sont détaillés
dans le [compte rendu de publication](release-1.0.24.md).
