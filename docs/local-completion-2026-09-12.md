# SalaTime — modifications locales du 12 septembre 2026

Cette tranche est préparée localement. Aucun push Git, déploiement du site ou du backend, envoi Google Play ou publication Shorebird.

**Mise à jour ultérieure :** les réglages de notifications ont été entièrement remplacés et leurs activations alignées sur Moadine à la demande de l’utilisateur. Le détail et les livrables actuels figurent dans [le nouveau bilan](notification-settings-2026-09-12.md). Les valeurs et empreintes ci-dessous décrivent la tranche précédente.

## Application et apparence

- Vert de référence `#2F5233`, variantes adaptées au mode sombre, harmonisés dans les thèmes mobiles, la Qibla, les widgets et les pages publiques du site.
- Thèmes clair/sombre/automatique conservés dans les paramètres et inclus dans la sauvegarde du compte.
- Nouvelle boussole vectorielle Qibla avec orientation native, indications lisibles et identité SalaTime.
- Pendant les 90 premières minutes suivant une prière, affichage du temps écoulé ; ensuite, décompte vers la prochaine prière. Lever du soleil exclu de cette phase, passages de minuit et horaires corrigés couverts.
- Affichage adapté aux petits écrans, aux grandes tailles de texte et à l’arabe ; correction du chevauchement avec la barre d’état Android et des dates restant en anglais.
- Les icônes et l’horaire de la prière active utilisent la nuance verte claire du thème sombre pour conserver leur contraste.

## Horaires, rappels et widgets

- Choix des méthodes de calcul et corrections de chaque horaire, lever du soleil inclus ; calculs, accueil, rappels et widgets utilisent les corrections.
- Rappels avant/après désactivés par défaut, sélection distincte des sons dès la première configuration.
- Widgets petit, moyen et grand, proposition facultative une fois après la configuration initiale, ajout depuis les paramètres.
- Secondes facultatives, opacité/transparence, ville, date et illustration configurables. Compteur Android natif sans réveil applicatif chaque seconde.
- Rappels Duha, dernier tiers de la nuit, vendredi, matin/soir, jeûne lundi/jeudi et jours blancs ; désactivés par défaut, réglables séparément.
- Silence automatique facultatif sur Android 10+, avec une règle propre à SalaTime et autorisation Android ; respecte les autres règles et ne s’active pas simplement par restauration cloud.
- Calendrier islamique, événements, conversion de date, correction hégirienne, horaires mensuels et partage des horaires en image/texte.
- Verset quotidien et commentaire issus des ressources déjà présentes, avec référence cohérente entre traductions et repli si le commentaire manque.
- Canaux Android sans badge et nettoyage des notifications déjà reçues sans annuler les alarmes à venir.

## Sons

La demande finale remplace les sons intégrés par les **68 fichiers audio** de Moatheni 3.0.5 (63), copiés depuis l’APK installé sur le Samsung. Les anciennes clés de réglage sont conservées pour six correspondances ; les autres entrées ont des clés stables distinctes. L’option sans son reste disponible.

`assets/audio/catalog.json` consigne provenance, noms, durées et empreintes. Les MP3 Flutter/Android sont identiques aux fichiers de référence. `tool/import_notification_sounds.py` reproduit l’intégration depuis les ressources décodées fournies. Aucun code de l’application de référence n’a été incorporé.

L’import de fichiers personnels demeure disponible sur Android. Les fichiers sont copiés dans un répertoire privé, contrôlés, dédupliqués et conservés après suppression du fichier d’origine. Un fournisseur Android propre aux sons corrige l’échec réel rencontré avec le fournisseur d’images.

Sur iOS, les sons de notification sont encodés en AIFF IMA4 et limités à moins de 30 secondes ; les préécoutes MP3 restent complètes. Cette limite provient de [la documentation Apple](https://developer.apple.com/documentation/usernotifications/unnotificationsound). Compilation et écoute sur iPhone non effectuées depuis Linux.

## Comptes et préférences

- Inscription/connexion par e-mail, vérification par code, récupération du mot de passe, déconnexion et suppression du compte.
- Intégrations Google/Apple avec vérification serveur des identités, configuration explicite et liaison d’un fournisseur au compte existant.
- Comptes mobiles séparés des comptes administrateurs ; mots de passe hachés et jetons conservés dans le coffre de l’appareil.
- Préférences enregistrées dans la base Laravel avec versionnement, changements hors ligne, reprise automatique, fusion des modifications indépendantes et choix explicite en cas de conflit.
- Protection contre les réponses tardives d’un ancien compte et les sessions révoquées ; stabilité du synchroniseur lors du passage des nombres JSON entre Dart et PHP.
- Aucune coordonnée GPS, permission système, clé d’accès ou URI de fichier personnel dans les préférences envoyées. Les sons personnels restent locaux et utilisent un remplacement intégré sur un autre appareil.

Les identifiants OAuth Google/Apple n’étaient pas présents. Les connexions réelles à ces fournisseurs, les droits de signature iOS et l’activation du backend restent à configurer avant une future publication autorisée. Les boutons indisponibles sont masqués. Les mails de validation ont uniquement été écrits dans un journal local de test, sans envoi SMTP.

Configuration : `docs/auth/README.md` côté application et `web/documentation/mobile-account-api.md` côté backend.

## Vérification sur Samsung

Les essais utilisent **SalaTime Test** (`net.salatime.app.preview`) sur Samsung SM-S901U / Android 12. La signature Play de l’application existante diffère de la clé locale ; la prévisualisation est donc installée en parallèle, sans remplacer SalaTime ni ses données.

Vérifications réalisées :

- configuration initiale française, avant/après désactivés et choix sonore conditionnel ;
- import personnel puis suppression du fichier source ;
- alarme reçue à l’heure et lecture native achevée en arrière-plan après correction ;
- proposition de widget au premier lancement, ajout réel du grand widget One UI et secondes fonctionnelles ;
- Qibla active avec capteur, carte d’accueil sans chevauchement de la barre d’état ;
- passage réel du décompte Maghrib au temps écoulé dans l’application et le widget ;
- inscription et vérification e-mail via l’API et une base SQLite temporaires isolées ;
- modification des préférences par une seconde session puis restauration visible sur le Samsung ;
- session retrouvée après redémarrage, état « préférences à jour » stable et suppression du compte via l’interface (zéro compte, préférence ou token de test restant) ;
- recherche de tonalités sans accents, choix de Tonalité 3 et lecture native achevée à l’heure en arrière-plan.

Le serveur local de test a été arrêté après les essais, et son journal de codes mail supprimé. La prévisualisation finale utilise de nouveau l’adresse habituelle du backend, dont les nouvelles routes attendent une publication autorisée. Le son personnel synthétique et les identifiants de test sont retirés.

Captures de contrôle : `/tmp/salatime-completion-qa/`.

APK installé et disponible localement : `/home/hemiad/Downloads/SalaTime-test-1.0.15-18.apk`. Les notifications de cette prévisualisation sont désactivées pour éviter des doublons avec l’application Play existante ; elles peuvent être activées dans ses paramètres.

Empreintes SHA-256 des livrables finaux :

- APK de test : `562adda285091df0f55bf2167cfc280f9c68e437e1c2def7afbc349a476caaff`.
- AAB local `build/app/outputs/bundle/release/app-release.aab` : `4a6f4bdc61a5d3f8e227ddc9afef6a8d52ef0883d9eaaf97f4b8df04993e63b7`.

## Validation automatisée

- 78 tests Android réussis, dont accès au son privé, alarmes, widgets, catalogue et silence automatique.
- 46 tests web/backend / 53 770 assertions réussis, dont 16 tests de comptes mobiles (146 assertions). Toutes les bases et les notifications de test sont isolées.
- Contrôle des 68 MP3 et de leurs empreintes ; 68 ressources iOS valides, sous 30 secondes.
- 184 tests Flutter réussis et analyse complète sans anomalie. Sélecteurs contrôlés en français/arabe sur 320 px, texte ×2 et clavier.
- Compilation Android release réussie : AAB de 121,9 Mo, architectures arm64-v8a, armeabi-v7a et x86_64 ; les 68 fichiers sonores sont présents et identiques aux sources.

La validation automatisée et les essais Android ne constituent pas une validation OAuth réelle Google/Apple ni un test sur iPhone. Les fonctionnalités natives exigent une nouvelle version Android ; un simple patch Dart Shorebird ne suffit pas.
