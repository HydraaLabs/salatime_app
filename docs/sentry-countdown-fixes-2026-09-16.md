# Correctifs Sentry et priorité de la prochaine prière

## Coran : SALAMTIME-6 et SALAMTIME-7

Le défilement du lecteur hors ligne reproduit `GetBuilderState.initState:134`,
« Null check operator used on a null value ». La première page devient
propriétaire du contrôleur partagé des favoris et le supprime lorsqu'elle sort
du viewport. Les pages suivantes ne peuvent plus récupérer ce contrôleur.

Les boutons de favoris des deux lecteurs ne détruisent plus ce contrôleur.
Sa factory peut être recréée après fermeture de route. Le lecteur hors ligne
accepte également l'absence de texte à surligner.

Le test de régression utilise un écran de 288 × 448, un contrôleur initialisé
paresseusement, puis les pages 0, 20, 25 et 0. Il vérifie la conservation du
contrôleur et l'affichage d'un favori après retour. Il reproduit l'erreur avant
le correctif et passe après.

## Autres erreurs auditées

- SALAMTIME-1 : protections natives contre les valeurs NaN déjà présentes ;
  les deux tests Kotlin `MathUtilsTest` passent.
- SALAMTIME-2 : l'observateur du compte lit déjà l'utilisateur pendant le
  chargement. Un nouveau test maintient la configuration en attente, puis
  vérifie l'apparition du formulaire sans erreur GetX.
- SALAMTIME-3 et SALAMTIME-4 : les tests existants de réglages français et de
  navigation du Coran passent, notamment sur écran étroit avec texte agrandi.
- SALAMTIME-5 reste ouvert : un événement ANR de la version 1.0.15+18, dans
  `FlutterJNI.nativeSurfaceCreated`. Les traces disponibles ne contiennent pas
  le thread raster permettant d'identifier la cause. Aucun changement spéculatif
  du moteur de rendu n'est présenté comme une correction de cet incident.

## Décompte

À une heure ou moins de la prochaine prière, celle-ci remplace l'affichage du
temps écoulé depuis la précédente. Le décompte reste normal à exactement
45 minutes et devient rouge en dessous. L'accueil classique et moderne, les
widgets Android/iOS et la notification Android appliquent ces seuils.

Les rafraîchissements natifs incluent la transition à une heure et le seuil
rouge, même si l'application est fermée. Les ajustements d'horaires et le
passage à la journée suivante sont couverts côté Flutter.

## Validation et livraison

- Analyse Flutter : aucune anomalie.
- Suite Flutter : 546 tests réussis.
- Suite native Android : 200 tests réussis ; deux tests de boussole réussis
  séparément.
- APK de test compilé, package vérifié `net.salatime.app.preview`, version
  1.0.21+24. Sentry désactivé pour cette compilation de test afin de ne pas
  produire de faux événements de production. SHA-256 :
  `08680911f2fb455e525b194bf08d5cd76cb9e7ce64554a7581a2e07b192ad385`.
- Samsung non détecté à la fin des vérifications : cet APK corrigé n'a pas
  encore été installé ni validé sur l'appareil.
- Tests iOS ajoutés ; exécution Xcode et appareil iOS non vérifiée sur Linux.
- Aucun problème marqué résolu dans Sentry, aucune publication Git/Play/serveur
  effectuée par ce correctif local.
