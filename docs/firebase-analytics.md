# Firebase Analytics dans SalaTime

## Projet et propriété

Configuration identifiée pour SalaTime :

| Élément | Valeur |
| --- | --- |
| Projet Firebase | `salatime-e3ed1` |
| Numéro du projet Firebase | `436624512066` |
| Offre Firebase | Spark, gratuite |
| Compte Google Analytics existant | `411117298` |
| Propriété GA4 existante | `557880725` |
| Identifiant de l'app Android et bundle iOS | `net.salatime.app` |
| Flux Analytics Android | `16063889810` |
| Flux Analytics iOS | `16063981094` |

Les identifiants de projet et les fichiers de configuration **client** Firebase
(`google-services.json`, options Flutter et éventuel `GoogleService-Info.plist`)
identifient une app publique ; ce ne sont pas des clés privées de signature ou
des identifiants Firebase Admin. Ne pas les confondre avec un fichier de compte
de service, une clé privée Apple ou les mots de passe de signature.

## Données suivies

`AnalyticsScreenCatalog` contient 46 noms fixes de pages et fonctionnalités.
Le navigateur et les onglets signalent la page effectivement visible. La liste
inclut notamment l'accueil, la Qibla, les mosquées, les sourates, le lecteur,
les récitateurs, le compte et les paramètres. Les pages ouvertes depuis le cache
local sont également comptées : ce suivi ne dépend pas d'un appel API.

Les événements d'action sont limités à :

| Événement | Déclenchement |
| --- | --- |
| `account_sign_in` | Connexion réussie, après sauvegarde effective de la session |
| `account_sign_up` | Inscription par e-mail réussie, après sauvegarde de la session |
| `account_sign_out` | Déconnexion réussie et nettoyage de la session |
| `cloud_sync` | Préférences entièrement synchronisées avec le compte |

Ces actions n'ont aucun paramètre applicatif. Les vues d'écran envoient uniquement
un nom du catalogue et la classe fixe `SalaTime`, via l'événement standard
`screen_view`. Les URL brutes, requêtes, arguments de route, e-mails, noms,
identifiants de compte, tokens, coordonnées GPS précises, recherches, versets,
choix de récitation et historique personnel de lecture sont exclus.

Firebase ajoute ses données techniques et événements standards : instance
d'installation pseudonyme, ouvertures et sessions, engagement, versions de l'app
et du système, modèle d'appareil et éventuelle géographie approximative issue du
réseau. Ces statistiques ne doivent donc pas être présentées comme totalement
anonymes. L'app ne définit aucun `user_id` Analytics. Les identifiants publicitaires
et la personnalisation publicitaire sont désactivés.

## Démarrage et performances

Le service est créé avant `runApp`, puis son initialisation est lancée **après**
`runApp` sans être attendue par l'écran d'accueil. Il dispose d'une petite file
mémoire limitée à 24 événements et d'un délai maximal pour les opérations SDK.
Une configuration indisponible ou un échec de statistiques n'empêche pas d'ouvrir
l'app, de se connecter ou de calculer les prières.

Le SDK Firebase gère le transport et l'envoi différé. Les statistiques partent
directement de l'app vers Google : aucun point d'accès de statistiques, stockage
analytique ou calcul de rapports n'est ajouté à l'hébergement SalaTime. Les
requêtes métier d'authentification et de synchronisation restent inchangées.

## Choix utilisateur et versions de test

Dans **Paramètres → Statistiques d'utilisation**, chaque utilisateur peut activer
ou désactiver la collecte, y compris sans compte. Le choix `analytics_enabled`
est conservé localement. Les versions de production l'activent par défaut après
initialisation ; la collecte native est initialement désactivée, le temps
d'appliquer les choix et l'exclusion des usages publicitaires.

La désactivation vide la file de l'app et demande au SDK d'arrêter la collecte,
de supprimer ses données locales et de renouveler son identifiant d'instance.
Elle ne supprime pas les statistiques déjà traitées chez Google. Le réglage n'est
pas synchronisé vers le compte : il concerne l'installation actuelle.

Les builds debug/profile et le compagnon `net.salatime.app.preview` ne doivent
pas alimenter les statistiques de production. Android utilise également la
métadonnée native `firebase_analytics_collection_deactivated` pour éviter qu'une
préférence SDK persistante n'active une version de test avant Flutter. Les tests
debug volontaires nécessitent les deux options `SALATIME_ANALYTICS_DEBUG=true`
et la propriété Gradle `salatimeAnalyticsDebug`; le compagnon preview reste exclu.

## Configuration native

- Android utilise le plugin `com.google.gms.google-services` version `4.5.0`
  pour l'app principale. Le plugin n'est pas appliqué au compagnon preview.
- iOS utilise `FirebaseAnalytics/Core`, sans capacité de collecte IDFA, et
  désactive aussi IDFV. Le bootstrap utilise les options Firebase Dart
  explicites de l'app iOS. Le fichier original est conservé dans
  `config/firebase/GoogleService-Info.plist`, hors des ressources Xcode, pour
  éviter l'auto-configuration par le plugin avant le démarrage Flutter.
- La phase iOS **Thin Binary** applique au plist compilé la valeur booléenne
  `FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED` : vrai pour Debug/Profile, faux
  pour Release, avant la signature. Le script conserve les autres données et
  le format XML/binaire. `SALATIME_ANALYTICS_DEBUG=true` dans les Dart defines
  déverrouille volontairement ce garde pour DebugView.
- Le suivi automatique des écrans natifs est désactivé. Seul le catalogue
  explicite décrit les pages Flutter, ce qui évite d'enregistrer des routes ou
  données non prévues.

Les configurations originales Android/iOS ont été validées pour le projet
`salatime-e3ed1` et l'identifiant `net.salatime.app`. La console confirme la
liaison des deux flux à la propriété GA4 existante. Les compilations Android
debug et release ont réussi ; leurs ressources Firebase générées et manifestes
fusionnés ont été contrôlés. Les permissions publicitaires sont absentes,
la collecte initiale reste désactivée et le garde natif est actif pour debug.
Les tests du garde iOS passent sous Linux ; l'archive Xcode et la réception
d'événements sur appareil physique restent à vérifier. Ce document ne vaut pas
preuve d'événements reçus.

## Livraison

L'ajout de Firebase comprend de nouvelles dépendances natives : il faut compiler
et distribuer un nouveau binaire Android et iOS. Un correctif Shorebird seul ne
peut pas installer ces SDK dans un binaire qui ne les contient pas.

L'intégration est préparée localement. Aucun push, déploiement de la politique
publique ou envoi aux stores n'est implicite dans cette préparation. Pour une
livraison, joindre la section de confidentialité
`web/resources/views/support/partials/analytics-privacy.blade.php` et mettre à
jour les déclarations des stores avec les données effectives du SDK. Le détail
de transparence figure dans
`web/documentation/firebase-analytics-privacy.md`.

## Références

- [Démarrage Firebase Analytics pour Flutter](https://firebase.google.com/docs/analytics/flutter/get-started)
- [Contrôle de la collecte](https://firebase.google.com/docs/analytics/configure-data-collection)
- [Données collectées par Firebase Analytics](https://support.google.com/firebase/answer/6318039)
