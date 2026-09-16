# SalaTime Android 1.0.21+24

Package de production : `net.salatime.app`.

## Modifications

Une seule notification de prière est conservée et actualisée : temps écoulé
vert pendant la première heure après l’adhan, puis décompte vers la prochaine
prière, rouge pendant la dernière heure. Les rappels se remplacent et expirent
au bout d’une minute au maximum. Les anciennes notifications sont nettoyées
sans annuler les futures alarmes. Après la lecture audio, le suivi utilise un
canal silencieux de faible importance, sans badge.

Cette version embarque aussi les changements déjà présents sur main : fusion
fiable des lectures locales à la connexion, invitation à noter après trois
jours d’utilisation et retrait des entrées alphabet, noms et fonds d’écran.

## Validation et publication

Préflight distant du 16 septembre 2026 : Play production 1.0.20/code 23,
Shorebird Android actif 827176/1.0.20+23. Le code 24 est disponible.
Les 140 tests Android ciblés passent (SDK Android 24 et 33 simulés).
Les modifications natives nécessitent une release complète, avec Flutter
Shorebird 3.41.6, identique à la version de production précédente.
Aucun appareil Samsung connecté pendant cette publication ; la validation
physique de cette version reste à effectuer.

Les 540 tests Flutter passent avec le SDK de publication 3.41.6.

L’analyse complète Flutter 3.41.6 ne signale aucune anomalie.

## Publication vérifiée le 16 septembre 2026

Commit source : `c998610b0bf6f730bff161adefcbb7f9f564f6b9`, poussé sur
`HydraaLabs/salatime_app`, branche main.

Shorebird : release Android active `833116`, artefact `3695429`, Flutter 3.41.6.
Le bundle distant a été téléchargé et comparé au bundle signé validé :
143182669 octets, SHA-256
`29107ad02373bc3521fb3b490708dfee927853b549231ba6e6ba2f4836f5ae29`.
Le package, la signature, les trois architectures Android, le récepteur privé
de nettoyage, les 68 sons et les 1141 fichiers de traduction sont vérifiés.

Google Play : bundle identique téléversé, édition production validée et
commitée. Une nouvelle édition de lecture confirme 1.0.21/code 24, statut API
`completed`, et le même SHA-256. Les autres pistes sont inchangées.
La Console confirme « Modifications en cours d’examen », avec vérifications
rapides en cours et envoi automatique pour examen à leur issue. Publication
gérée désactivée. La disponibilité publique sur Play n’est pas encore confirmée.

APK universel signé issu du même AAB : 166576183 octets, SHA-256
`d4e78fd6537b8b8efa94aedc31c433e2f3e467f3846cf19cf17c0164d858ae0a`.
Les trois téléchargements publics répondent HTTP200 et correspondent à cette
empreinte, avec cache BYPASS :

- https://salatime.net/dl/SalaTime-1.0.21-24.apk
- https://salatime.net/dl/salatime.apk
- https://salatime.net/app-release.apk

Les anciens alias ont été sauvegardés avant installation ; neuf autres fichiers
et configurations protégés sont inchangés. Aucun déploiement backend.

Reçus locaux : `/tmp/salatime-play-1.0.21-publication.json`,
`/tmp/salatime-1.0.21-shorebird-verified.json`,
`/tmp/salatime-1.0.21-aab-verification.json`,
`/tmp/SalaTime-1.0.21-24.audit.json` et
`/tmp/salatime-web-release-1.0.21-audit/`.
