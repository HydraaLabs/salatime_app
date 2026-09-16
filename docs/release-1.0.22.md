# SalaTime Android 1.0.22+25

Package de production : `net.salatime.app`. Publication autorisée après la
validation de SalaTime Test sur le Samsung, dans la nuit du 16 au 17 septembre.

## Changements

La méthode de calcul peut être sélectionnée automatiquement selon le pays de
la position ou de la ville choisie. Les choix manuels existants, l'école de
calcul et les corrections personnelles sont conservés. Une option Ramadan
propose Isha à 90 ou 120 minutes après Maghrib, uniquement pendant les nuits
du mois hégirien corrigé de l'application.

Android arme une fenêtre de trois jours calendaires et conserve une réserve
hors ligne allant jusqu'à 30 jours. Le renouvellement natif et la préparation
par lots réduisent le nombre d'alarmes et les écritures de programmation.
La réserve est prolongée à l'ouverture de l'application. Les notifications
de prière utilisent une priorité élevée tout en respectant le silence.

Les onze méthodes communes au moteur public Adhan de la référence ont été
alignées, avec vérification indépendante de 1 232 cas. La dépendance MIT est
conservée avec sa licence ; aucun code ou son propriétaire de la référence
n'est ajouté. Les corrections locales de décompte et de cycle de vie des
lecteurs du Coran présentes dans l'APK Samsung sont également incluses.

## Préflight et validation

Le préflight distant du 17 septembre confirme Play production 1.0.21/code 24
et Shorebird Android actif 833116/1.0.21+24. La version 1.0.22+25 est libre.
Git local et distant sont initialement sur `58bdd909fe5ac3b33cde094fd0303c8de9a85046`.
Le build de production conserve Shorebird Flutter 3.41.6.

Avant préparation de la release : 590 tests Flutter et 216 tests Android
réussis, analyse Flutter sans problème. Le Samsung SM-S901U, Android 12, a
reçu le réveil de test écran en veille et processus arrêté avec 948 ms de
retard. Le silence est respecté ; son audible et bannière ne sont pas
validés par cet essai. La rotation après minuit est observée : 45 réveils
de prière actifs pour 435 occurrences en réserve. Les détails et limites
sont dans [le compte rendu appareil](prayer-three-day-window-2026-09-16.md).

Les 590 tests Flutter passent également avec le SDK de publication Shorebird
Flutter 3.41.6 ; son analyse complète ne signale aucun problème.

Les modifications iOS ne font pas l'objet d'une publication.

## Source et Shorebird vérifiés

Commit source poussé sur `HydraaLabs/salatime_app`, branche main, puis relu :
`2e9e9d6e9674a20b5c3e167857b6ee4f9e12e7f6`.

Shorebird : release Android active **835456**, artefact **3706136**,
Flutter 3.41.6. Le bundle distant téléchargé intégralement correspond au
bundle signé local : **143240669 octets**, SHA-256
`3a4849347b4443250fbf5fd1ab3bd7002a8d8064379073ce08a05ba8d479462b`.
Package de production, version, signature, receiver de renouvellement privé,
batch natif et canal de lecture vérifiés. Les trois architectures, 68 sons,
1141 fichiers de traduction du Coran et le catalogue Athkar sont présents.

Une modification concurrente du service de connexion Apple est intervenue
après la compilation Dart. Le kernel contient exactement le fichier du commit
et pas cette modification. Les trois bibliothèques finales correspondent à
celles du bundle, avec raccord des étapes AOT et suppression des symboles.
Les modifications concurrentes ultérieures de connexion et d'iOS restent
locales et hors de cette release. Reçu :
`/tmp/salatime-1.0.22-source-provenance.json`.

L'APK universel signé est dérivé de ce même AAB : **166641719 octets**,
SHA-256 `0286f6c135df9e003dc07f67b2b4afd43d191a33876713234d89442999846d0b`.
Son certificat de distribution directe correspond à celui des APK précédents.
Reçus : `/tmp/salatime-1.0.22-aab-verification.json`,
`/tmp/salatime-1.0.22-shorebird-verified.json` et
`/tmp/SalaTime-1.0.22-25.audit.json`.

## Google Play vérifié

Le même bundle a été téléversé, puis l'édition de production validée et
commitée. Une nouvelle édition de lecture confirme **1.0.22/code 25**,
statut API `completed` et SHA-256 identique. Les autres pistes sont
inchangées ; l'édition de vérification est supprimée avec HTTP 204.
Reçu : `/tmp/salatime-play-1.0.22-publication.json`, phase `verified`.

La Console affiche **1.0.22** dans « Modifications en cours d'examen »,
avec vérifications rapides automatiques en cours et envoi pour examen à
leur issue. Publication gérée désactivée. Les déclarations Sécurité des
données et services de premier plan déjà soumises sont conservées.
La disponibilité publique sur Google Play n'est pas encore confirmée.
Capture textuelle : `/tmp/salatime-1.0.22-console-after.txt`.

## APK du site disponible

Les trois liens ont été téléchargés intégralement : HTTP 200, type APK,
cache Cloudflare BYPASS, taille et SHA-256 identiques à l'APK signé validé.

- https://salatime.net/dl/SalaTime-1.0.22-25.apk
- https://salatime.net/dl/salatime.apk
- https://salatime.net/app-release.apk

Les deux alias précédents sont sauvegardés et dix fichiers historiques ou
de contrôle d'accès sont conservés sans modification. Aucun déploiement
backend. Sauvegarde privée :
`/home/bshttdz/.salatime-apk-1.0.22-25-20260916T231929Z-0c0410cdfcef`.
Reçus : `/tmp/salatime-web-release-1.0.22-audit/apk-deployment-result.json`
et `apk-public-readback.json` dans le même dossier.
