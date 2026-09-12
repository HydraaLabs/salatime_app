# Activation des comptes SalaTime — 12 septembre 2026

Demande : activer la connexion Google et l’inscription par email. Le périmètre distant est limité aux comptes, à la synchronisation des préférences et à leurs informations de confidentialité. Aucun push Git, aucune publication Play ou Shorebird dans cette intervention.

## Google Cloud

Configuration créée et relue dans le projet `salatime` (`867941996913`). L’audience OAuth est **Externe / En production**. Le nom présenté est SalaTime, le domaine autorisé `salatime.net`, la page d’accueil `https://salatime.net` et la confidentialité `https://salatime.net/privacy-policy`.

Les seules autorisations déclarées sont `openid`, `userinfo.email` et `userinfo.profile`, affichées par Google parmi les niveaux non sensibles. Aucune autorisation sensible ou restreinte n’a été ajoutée.

Ces identifiants clients sont publics. Aucun secret client Google n’est requis ni intégré à l’application pour la validation des ID tokens.

| Client | Identifiant | Package / SHA-1 |
| --- | --- | --- |
| SalaTime Mobile API | `867941996913-gmugbqtbqap3psturjrutl7utpuk2f28.apps.googleusercontent.com` | Client Web utilisé comme audience serveur |
| SalaTime Android Preview | `867941996913-hbhok6nv97tuk64hjuh5h04cl80blnch.apps.googleusercontent.com` | `net.salatime.app.preview` / `9E:9B:17:90:B4:FB:B0:BE:29:44:D1:2D:9E:BB:F7:56:77:41:55:27` |
| SalaTime Android Google Play | `867941996913-nkfrjp4cia45deb9oksg15b052nmcfu7.apps.googleusercontent.com` | `net.salatime.app` / `74:35:5E:E2:3B:16:96:55:39:75:F0:55:0B:BC:6A:45:00:2F:05:ED` |
| SalaTime Android Signed APK | `867941996913-ujmgrelbptc8l03n8c4e5ntsk8lfu3mp.apps.googleusercontent.com` | `net.salatime.app` / `00:84:E8:31:16:A0:5D:07:A9:37:0C:66:67:81:F3:05:BE:87:AA:70` |

Le certificat Play a été extrait de l’APK réellement installé sur le Samsung SM-S901U et vérifié avec `apksigner`. Cela ne constitue pas un inventaire de futures rotations de certificat Play : ajouter toute nouvelle signature avant de distribuer une version qui l’utilise.

## Version de test et correction locale

APK conservé dans `/home/hemiad/Downloads/SalaTime-test-comptes-1.0.15-18.apk`. La version `net.salatime.app.preview` a été reconstruite avec l’API HTTPS habituelle et installée avec conservation des données sur le Samsung. SHA-256 de l’APK : `b9e78a464cc945b536bd6a49d9ee934738114a719037d2b20dbebbad0fa11c0c`.

Le bouton Réessayer relit désormais le stockage sécurisé après une panne temporaire. Une lecture tardive ne peut ni rétablir une session après déconnexion ni remplacer une nouvelle connexion. Les 22 tests Flutter de service/écran passent ; analyse ciblée sans problème. Les modifications précédentes de synchronisation à une minute et de programmation des alarmes en arrière-plan sont conservées.

La configuration du serveur n’annonce Google actif que si le client Web figure aussi dans les audiences autorisées. Les tests de configuration et de validation des identités passent.

## Serveur et validation réelle

Avant activation, `/api/mobile/auth/config` ne fournissait pas la configuration attendue. L’audit OVH a confirmé l’absence des routes, classes et tables de comptes. Le SMTP effectif existant utilise le transport SMTP configuré dans l’administration ; la présence d’identifiants ne prouve pas la réception des emails.

Le paquet ciblé a été installé sur OVH avec sauvegarde privée. Le rapport de déploiement est `web/documentation/mobile-account-activation-2026-09-12.md`. Configuration publique : HTTP 200 ; compte et préférences sans jeton : HTTP 401 ; inscription avec champs invalides : HTTP 422. Le client Web Google retourné est conforme.

Sur Samsung, les formulaires d’inscription et de connexion sont visibles, et le bouton Google ouvre le sélecteur natif des comptes. L’utilisateur a ensuite validé sa connexion : sa capture montre le compte connecté, et une lecture agrégée a confirmé 1 compte mobile, 1 identité Google et 1 document cloud non vide, sans lire les préférences ni les jetons.

Le serveur récupère les clés publiques Google en HTTPS (HTTP 200). Mailgun est désormais configuré pour les comptes uniquement, sans modifier l’ancien SMTP général ni ses paramètres en base. Le domaine `salatime.net` a ses enregistrements SPF et DKIM vérifiés ; un compte SMTP dédié a été créé. Le véritable transport Symfony `mobile_accounts` a validé STARTTLS, le certificat et l’authentification SMTP 235 depuis PHP web sur OVH. La configuration publique, relue indépendamment en HTTP 200, annonce la vérification des emails et la récupération de mot de passe actives. Aucun email n’a été envoyé pendant ces contrôles : la réception reste à vérifier lors d’un usage réel. Les sondes temporaires ont été supprimées, leurs URL renvoient 404, et le fichier local de transfert des identifiants a été supprimé après contrôle de la configuration et de sa sauvegarde privée. Les mots de passe ne figurent pas dans les rapports. Sauvegarde serveur : `/home/bshttdz/.salatime-mailgun-accounts-20260912T215152Z` ; détails dans le rapport backend.

## Débordement dans les paramètres

Le dépassement sur la ligne du format 24 h est corrigé : son texte revient à la ligne et l’interrupteur reste visible. Le titre et les noms de ville longs s’adaptent à la largeur ; les listes de méthode et de madhab affichent les choix longs sur plusieurs lignes dans leur menu. Le chargement des réglages a aussi été déplacé hors du builder, qui relançait auparavant une relecture à chaque notification du contrôleur. Le changement de format reste réactif et persistant.

Le test de régression sur les anciens fichiers reproduit un dépassement de 197 pixels à droite en français, thème sombre, largeur 360 px. Les fichiers corrigés passent 7 tests widget : 320/360 px, thèmes clair/sombre, texte normal/doublé, changement de format, menus longs et absence de rechargement récursif. Analyse Dart ciblée sans problème. Captures locales : `/tmp/salatime-prayer-settings-qa/`.

APK corrigé : [SalaTime-test-comptes-corrige-1.0.15-18.apk](/home/hemiad/Downloads/SalaTime-test-comptes-corrige-1.0.15-18.apk), SHA-256 `e4302f83da49676fa4231817c0b835dbb1227ee3e1d746cd30b2e7532d6ed8f0`. Compilation debug demandée pour Android arm64, application `net.salatime.app.preview` / SalaTime Test, API `https://salatime.net`, même certificat debug SHA-1 `9E:9B:17:90:B4:FB:B0:BE:29:44:D1:2D:9E:BB:F7:56:77:41:55:27`. Les bibliothèques des plugins ajoutent aussi armeabi-v7a et x86_64 au manifeste des bibliothèques natives du paquet ; aucune validation de cet APK sur ces deux architectures n’est revendiquée.

Le Samsung est absent de la liste ADB au dernier contrôle : cet APK corrigé n’a pas encore été installé ou vérifié physiquement. La version Play et ses données sont inchangées. Aucune publication Play/Shorebird ni aucun push Git.
