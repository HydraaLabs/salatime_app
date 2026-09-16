# Compte SalaTime : configuration et validation

Les écrans Flutter et l’API Laravel sont distincts de la publication Play/Shorebird. Aucun identifiant de fournisseur n’est intégré au dépôt.

## API

Par défaut, le client utilise `AppConstants.BASE_URL`. Pour une prévisualisation locale isolée :

```
adb reverse tcp:8877 tcp:8877
env ORG_GRADLE_PROJECT_salatimePreview=true 'ORG_GRADLE_PROJECT_kotlin.incremental=false' flutter build apk --debug --target-platform android-arm64 --dart-define=SALATIME_APPLICATION_ID=net.salatime.app.preview --dart-define=SALATIME_ACCOUNT_API_URL=http://127.0.0.1:8877
```

Le HTTP n’est admis que pour les hôtes de boucle locale en mode debug. Les versions diffusées exigent HTTPS. Le coffre stocke la session sous une clé dérivée de l’origine de l’API : une session de production n’est jamais envoyée à l’API de démonstration.

L’inscription et le changement de mot de passe demandent au moins 12 caractères, des lettres et des chiffres, avec un maximum de 72 octets UTF-8 imposé par le hachage bcrypt côté serveur. Vérification et récupération utilisent un code reçu par email. Le client ne journalise ni corps auth, ni mot de passe, ni token et n’utilise pas le cache HTTP commun de l’application.

## Google

Configurer un client OAuth Web pour la validation serveur et un client Android correspondant au package et à chaque empreinte SHA de signature autorisée. Les packages de production et de prévisualisation sont différents. Le `server_client_id` vient de `/api/mobile/auth/config`; aucun fichier Firebase n’est nécessaire dans ce mode.

Pour iOS : configurer le client OAuth iOS, ajouter le schéma URL inversé réel dans `ios/Runner/Info.plist` (fragment `google-url-types.plist.example`), puis activer `--dart-define=SALATIME_GOOGLE_IOS_ENABLED=true`. Le serveur doit retourner le `ios_client_id` réel. Tant que cette étape native n’est pas réalisée, le bouton est masqué sur iOS.

## Apple

Sur Android, créer le Service ID Apple, autoriser l’URL HTTPS `/api/mobile/auth/apple/callback`, configurer les identifiants et clé serveur. Le callback doit cibler le package fixé côté serveur et valider le `state`; les retours externes ne créent aucune session avant validation de l’identity token et du code par le backend. L’application utilise un nonce propre à chaque tentative.

Sur iOS : ajouter la capacité Sign in with Apple dans Xcode, configurer les droits de signature et renouveler le provisioning. Le fragment `apple.entitlements.example` indique la valeur attendue, sans remplacer les autres droits du projet. Activer ensuite `--dart-define=SALATIME_APPLE_IOS_ENABLED=true`. Le backend doit accepter l’App ID natif configuré, distinct du Service ID Android.

Configuration serveur pour l’app native : `MOBILE_APPLE_IOS_CLIENT_ID=net.salatime.app`, `MOBILE_APPLE_CLIENT_IDS` contenant cet identifiant, `MOBILE_APPLE_TEAM_ID`, `MOBILE_APPLE_KEY_ID` et `MOBILE_APPLE_PRIVATE_KEY_PATH`. Ce dernier désigne un fichier privé lisible par PHP, hors du répertoire public. Il s’agit d’une clé **Sign in with Apple** associée à l’App ID ; une clé API **App Store Connect** utilisée pour publier les versions ne la remplace pas. Aucun Service ID ou callback web n’est nécessaire pour la connexion native iOS.

L’API expose désormais `apple.ios_enabled` et `apple.android_enabled`. La nouvelle version iOS exige `ios_enabled=true` ; déployer cette API avant la build. Android exige un Service ID présent dans les audiences autorisées et son callback HTTPS. Grouper ce Service ID avec le même App ID Apple pour que les connexions Android et iOS correspondent au même utilisateur. Configurer également les domaines/adresses d’envoi du service de relais Apple pour les emails destinés à `privaterelay.appleid.com`.

Apple ne transmet le nom qu’à la première autorisation. Les connexions suivantes omettent ce champ et conservent le nom enregistré ; l’API accepte aussi le champ vide envoyé par les anciennes versions. Le client vérifie le `state` retourné et le backend vérifie la signature, l’audience et le nonce avant l’échange du code. Le refresh token est chiffré en base et révoqué avant la suppression du compte.

## Stockage et sauvegarde

`flutter_secure_storage` utilise le namespace Android `salatime_auth` avec RSA OAEP + AES-GCM; les données et clés enveloppées sont exclues des sauvegardes et transferts Android. Sur iOS, la session utilise le Keychain `unlocked_this_device` et ne migre pas vers un autre appareil. Les jetons ne sont pas des préférences synchronisables.

## Vérifications encore dépendantes des comptes fournisseur

Une configuration vide laisse seulement les méthodes réellement disponibles visibles. Tester Google sur un appareil certifié avec les empreintes de la build concernée, puis Apple sur Android et sur un iPhone signé avec le provisioning autorisé. La compilation et les tests avec fournisseurs simulés ne constituent pas une validation OAuth réelle.

Sources primaires :
- https://pub.dev/packages/google_sign_in_android
- https://pub.dev/packages/google_sign_in_ios
- https://pub.dev/packages/sign_in_with_apple
- https://pub.dev/packages/flutter_secure_storage
- https://developer.apple.com/documentation/signinwithapple/authenticating-users-with-sign-in-with-apple
- https://developer.apple.com/help/account/capabilities/configure-private-email-relay-service/
- https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple
