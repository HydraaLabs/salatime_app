# SalaTime — compatibilité et optimisations du 9 septembre 2026

Le dépôt était propre au départ, au commit `477be6b` (version `1.0.9+12`). Les modifications concernent uniquement l’application Flutter. Aucun déploiement Google Play, App Store ou Shorebird n’est effectué dans cet audit.

## Corrections

- **Compatibilité Android :** GPS, localisation réseau, boussole et accéléromètre déclarés facultatifs. La sélection manuelle de ville et la lecture restent accessibles sans ces capteurs. Ces déclarations évitent le filtrage matériel implicite lié aux permissions, conformément à la [documentation Android](https://developer.android.com/guide/topics/manifest/uses-feature-element).
- **Configuration iOS :** activation des gestionnaires `permission_handler` pour la localisation et les notifications. Dans la version installée, ces gestionnaires sont désactivés par défaut si leurs macros ne sont pas définies. Alignement des cibles Xcode sur iOS 14, déjà requis par le Podfile. Référence : [configuration officielle du plugin](https://github.com/Baseflow/flutter-permission-handler/blob/master/permission_handler/example/ios/Podfile).
- **Recherche du Coran hors ligne :** index construit uniquement à l’ouverture de la recherche ; lecture des fichiers sans conserver leur JSON brut dans le cache ; analyse et normalisation hors du thread d’interface, sourate par sourate. Les appels simultanés partagent le même chargement. Les 6 236 versets des 114 sourates sont conservés et une erreur ne laisse pas un index partiel en cache. La recherche utilise un index normalisé et un délai de 180 ms entre les frappes. Les traductions anglaises fournies par les fichiers de cet index sont maintenant recherchables.
- **Écran de recherche :** conservation de la saisie lors des reconstructions (clavier, rotation), bouton d’effacement fonctionnel, libération du contrôleur de texte et du minuteur. Libération du contrôleur d’onglets du Coran hors ligne.
- **Réseau :** un seul contrôleur, abonnement annulé à sa fermeture, gestion de plusieurs transports réseau et des erreurs natives. Un ancien contrôle initial ne remplace plus un événement récent. Les événements répétés ne relancent plus inutilement le réchauffement du cache des prières. La présence d’un transport réseau ne garantit pas l’accès à Internet ; les requêtes gardent leur propre gestion d’erreur.
- **Localisation automatique :** référence de déplacement actualisée après un rafraîchissement réussi, traitements sérialisés et protection contre les démarrages simultanés. Arrêter le service invalide les démarrages en attente. Un échec de récupération ne marque pas la position comme traitée.
- **Audio :** abonnements du contrôleur et du lecteur installés une seule fois ; abonnements du contrôleur libérés à sa fermeture ; chargement de la playlist groupé et opérations attendues. Arrêter le lecteur ne le détruit plus, ce qui permet de le réutiliser. Gestion d’un événement de fin sans playlist et protection contre les indices négatifs.
- **Images :** décodage des vignettes adapté à la taille affichée et à la densité d’écran, avec conservation du rapport largeur/hauteur.
- **Accessibilité :** débordements reproduits puis corrigés dans les raccourcis de l’accueil avec texte agrandi ; en-tête et tuiles adaptés à la taille du texte.

## Vérification

- `flutter analyze --no-pub` : aucune anomalie.
- `flutter test --no-pub` : **48 tests réussis**, dont les nouveaux tests réseau, audio, recherche et interface.
- Interface testée en français et arabe, avec texte ×2, aux dimensions logiques 320×568, 640×360 et 800×1024 : introduction et raccourcis sans débordement ; effacement et conservation de la recherche vérifiés séparément.
- Captures des raccourcis examinées localement avec polices chargées ; données et services natifs simulés dans les tests de widgets.
- `ruby -c ios/Podfile` : syntaxe valide.
- Compilation Android release et inspection de l’APK : voir les propriétés de l’artefact ci-dessous.

## Sentry et limites

La recherche Sentry ciblée sur `salamtime` a retourné un seul problème non résolu : [SALAMTIME-1](https://hydra-x6.sentry.io/issues/SALAMTIME-1), 18 occurrences et 8 utilisateurs au moment de la vérification. Le dernier événement examiné vient de `1.0.8+11`. Le correctif natif de boussole est déjà présent dans le commit de départ `477be6b` ; cet audit ne marque pas le problème résolu et ne prouve pas la distribution de sa correction aux utilisateurs.

Aucun téléphone Android ni environnement Xcode/iOS n’était disponible. La compilation iOS, les capteurs physiques, les politiques de batterie des constructeurs et le fonctionnement audio/notifications en arrière-plan doivent encore être vérifiés sur appareils. Aucun gain de batterie, mémoire ou FPS n’est chiffré : les suppressions de traitements et d’abonnements inutiles sont vérifiées par le code et les tests, sans profilage sur téléphone.

Le SDK Flutter installé impose Android API 24 au minimum (Android 7.0). Abaisser cette valeur sans changer et revalider le SDK et les dépendances ne constitue pas une compatibilité vérifiée.

## Artefact Android vérifié

- APK local : `build/app/outputs/flutter-apk/app-release.apk`.
- Version : `1.0.9+12` ; package `net.salatime.app`.
- Taille : 90,428,686 octets.
- SHA-256 : `d399174ab9793d814ec9cdbe12b66ca9c4e384be700b88d6b74a04df3426ed6c`.
- Minimum API 24 ; cible API 36 ; architectures `armeabi-v7a`, `arm64-v8a`, `x86_64`.
- Petits, moyens, grands et très grands écrans déclarés pris en charge.
- `zipalign -c -P 16 4` valide ; les 12 bibliothèques 64 bits ont des segments LOAD alignés sur au moins 16 Ko. Il s'agit d'une vérification statique, pas d'une exécution sur appareil 16 Ko.
- La date de l'APK est postérieure aux dernières modifications Dart ; compilation release finale réussie.
