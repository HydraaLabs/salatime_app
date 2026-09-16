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
