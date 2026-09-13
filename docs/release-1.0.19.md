# SalaTime Android 1.0.19+22

Package de production : `net.salatime.app`.

## Modification

Les écrans Avant, À l’adhan, Après et Autres notifications proposent chacun
une commande pour activer ou désactiver leur série en un geste. Les libellés
mentionnent la catégorie, par exemple « Désactiver l’avant athan » et
« Désactiver l’après athan » ; l’action inverse apparaît après désactivation.
Les commandes sont disponibles aussi pendant la première configuration.

La désactivation conserve sons et délais et annule uniquement les alarmes
concernées. Une seule écriture locale est effectuée ; la reprogrammation reste
en arrière-plan et la sauvegarde cloud intervient une minute après le dernier
changement. Le lever du soleil reste à activer individuellement, et le rappel
combiné lundi/jeudi retiré ne peut pas être réactivé par la commande globale.
Les échecs de persistance rechargent le stockage avant d’afficher une erreur.

Les huit nouveaux libellés sont traduits dans les dix langues. La langue système
est déjà utilisée au premier lancement lorsqu’elle est prise en charge ; un
choix explicite enregistré reste prioritaire. Cette règle n’a pas été modifiée.

## Préparation de publication

Préflight distant : Google Play production 1.0.18/code 21, code 22 libre ;
Shorebird Android dernière release active 826813/1.0.18+21, version 1.0.19+22 libre.
L’édition Play d’inspection a été supprimée (HTTP204). SDK release épinglé
Shorebird Flutter 3.41.6, identique à la release précédente. Aucun code Android
natif ni backend modifié. Publication explicitement demandée par l’utilisateur.

La version debug du correctif a été compilée avec Flutter 3.41.8 standard.
Le Samsung s’est déconnecté avant l’installation de ce dernier correctif ;
les tests automatisés ne constituent pas une validation physique du correctif.

## Validation du code publié

Les 116 tests ciblés passent avec le SDK release Flutter 3.41.6 : écrans,
persistance, reprogrammation des alarmes et synchronisation cloud. L’analyse
Flutter globale ne signale aucune anomalie. Les 22 tests d’écran et les captures
320 px/texte 200 % avaient aussi été contrôlés sur le SDK de test 3.41.8.
Aucun test natif n’a été relancé, le code Android natif restant inchangé.

## Artefacts et Shorebird vérifiés le 13 septembre 2026

Commit source : `53b4e74a53f958064aea98b699a4441395eab554`, poussé sur
`origin/main` et relu sur le dépôt distant avant compilation.

Shorebird : release `827067`, version `1.0.19+22`, Android `active`, artefact
`3667436`, Flutter `76ca3dff01cc7c5e6978e6b51e442777c6930419` (3.41.6).
L’AAB distant a été téléchargé intégralement et comparé au fichier local validé :
143 322 996 octets, SHA-256
`a54c2deed76f43db6f264ee65e2fb95d9227b62dc57c2b815ba049a0c339f52a`.

L’AAB signé non debug cible Android 36, minimum 24, pour `armeabi-v7a`,
`arm64-v8a` et `x86_64`. Vérification des 68 sons dans les assets et ressources
natives, 1 141 fichiers de traduction du Coran, catalogue Athkar, dix langues
d’interface, libellés français, récepteurs privés et contrôles audio natifs.

APK universel construit avec bundletool à partir de ce même AAB : 166 969 320
octets, SHA-256
`850fab8d588331acfecd95139fd68f39f4d20b7622b988e82b60cd89e71cd9e4`.
Signature vérifiée, certificat de distribution directe SHA-1
`00:84:E8:31:16:A0:5D:07:A9:37:0C:66:67:81:F3:05:BE:87:AA:70`.
Ce certificat est distinct de celui utilisé par Google Play App Signing.

Reçus locaux : `/tmp/salatime-1.0.19-aab-verification.json`,
`/tmp/salatime-1.0.19-shorebird-verified.json`,
`/tmp/SalaTime-1.0.19-22.audit.json`.

## Google Play API

L’AAB identique a été téléversé : version code `22`, SHA-256 identique au
fichier vérifié. La piste `production` a été validée, commitée puis relue dans
une nouvelle édition : release `1.0.19`, code `22`, statut API `completed`,
notes en français et anglais. Les autres pistes sont inchangées. L’édition
de vérification a été supprimée avec HTTP204.

Reçu : `/tmp/salatime-play-1.0.19-publication.json` (`phase: verified`).
Le statut API `completed` concerne le déploiement demandé ; il ne prouve pas
que Google a terminé son examen ni que la mise à jour est déjà publique.

La Console Play relue après le commit affiche bien `1.0.19` dans
« Modifications en cours d’examen », avec les vérifications rapides automatiques
en cours et l’envoi pour examen automatique à leur issue. La publication gérée
est désactivée ; aucun bouton d’envoi supplémentaire n’est en attente.
La déclaration Sécurité des données et la déclaration de services de premier
plan déjà soumises sont conservées. Dernière publication publique affichée :
12 septembre 2026. La disponibilité publique de `1.0.19` n’est pas confirmée.
Capture textuelle : `/tmp/salatime-1.0.19-console-after.txt`.

## APK du site

Les trois URL ont été relues intégralement après l’installation le
13 septembre 2026 à 11:15 UTC : HTTP200, MIME APK, cache Cloudflare `BYPASS`,
166 969 320 octets et SHA-256 identique à l’APK universel vérifié.

- https://salatime.net/dl/SalaTime-1.0.19-22.apk
- https://salatime.net/dl/salatime.apk
- https://salatime.net/app-release.apk

Les deux alias précédents ont été sauvegardés avant remplacement. Les cinq
archives antérieures et les deux `.htaccess` sont inchangés ; aucun fichier
backend ou de configuration n’a été déployé. Le journal serveur confirme
`success: true`, sept chemins protégés vérifiés, sans échec ni rollback.
Sauvegarde privée conservée :
`/home/bshttdz/.salatime-apk-1.0.19-22-20260913T111336Z-a53655c9f523`.

Reçus : `/tmp/salatime-web-release-1.0.19-audit/completion.json`,
`apk-deployment-result.json` et `apk-public-readback.json` dans le même dossier.
