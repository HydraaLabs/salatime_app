# SalaTime 1.0.27 — affichage des horaires au démarrage

Correctif : `1245f0fa1a6d317b2869620b9780c2f580d88896`.
Source des builds : `134899afc5da4befb41b6643dc11dbc1dd1b2ade`.
Android : `1.0.27+32`. iOS : `1.0.27 (36)`.

## Comportement

Avant d'ouvrir l'accueil, l'application prépare les horaires du jour depuis
la position ou la ville enregistrée, la méthode de calcul, le fuseau actuel
et les ajustements personnels. Les calendriers publiés sans coordonnées sont
lus dans le cache correspondant au jour demandé. Les horaires d'hier ne sont
pas réutilisés pour combler un manque de données.

La localisation et la recherche du nom de ville s'effectuent ensuite sans
effacer ces horaires. Le double géocodage au démarrage a été supprimé. En
l'absence de configuration locale, le parcours normal reste nécessaire pour
obtenir une position ou sélectionner une ville.

## Vérifications

- Analyse Flutter complète sans problème.
- 676 tests Flutter réussis avec les connexions Apple et Google iOS activées.
- Huit nouveaux tests de démarrage : restauration automatique/manuelle,
  méthode nationale, ajustements, format 12/24 heures, calendrier du jour,
  rejet du calendrier d'hier, configuration absente et erreur de fuseau.
- Les tests d'interface Android et iOS vérifient les six horaires dès le
  premier affichage, sans appel GPS, géocodage, permission ou HTTP.
- Compilation du simulateur et tests natifs iOS réussis sur le Mac de CI.
- Aucun nouvel essai sur appareil physique n'est revendiqué pour ce correctif.

## Distribution

État du 27 septembre 2026 : source poussée sur GitHub (`main` et
`fix/ios-location-review-20260924`).

- Android : patch Shorebird **1 stable** publié pour `1.0.27+31`, après
  vérification de compatibilité native et des ressources sans dérogation.
  Distribution confirmée sur ARM, ARM64 et x86_64.
- Google Play : nouveau build `1.0.27 (32)` envoyé par API, commit accepté
  et relu. Les vérifications automatiques sont terminées et la Console
  confirme « Vos modifications sont en cours d'examen ». Déploiement
  complet prévu après approbation, publication gérée désactivée.
- Les dix langues, les 70 captures téléphone, les 15 captures tablette
  7 pouces et les 15 captures tablette 10 pouces sont inchangées. Les autres
  pistes, les détails de l'application et la déclaration de service de
  premier plan sont conservés.
- iOS : build 36 signé et accepté par Apple (`VALID`), soumis le
  27 septembre 2026 à 15:40 UTC. Version et nouvelle soumission
  `4e47d694-cb0a-4542-b398-95c7417a32b5` en `WAITING_FOR_REVIEW`.
  Publication automatique après approbation (`AFTER_APPROVAL`). Les
  36 captures, trois localisations, la pièce jointe et les informations de
  démonstration sont conservées. Les notes décrivent le correctif.

Les nouveaux builds des stores ne sont pas encore confirmés comme
disponibles au téléchargement. L'AAB Android signé correspond à la source
indiquée et porte le SHA-256
`66162295d8b707f4f137dc3b0ad402670a4bd490e6ed282cdc0afd402eb226ad`.

Le build iOS provient de l'exécution GitHub
[`36327000308`](https://github.com/HydraaLabs/salatime_app/actions/runs/36327000308),
réussie à la seconde tentative après un délai de démarrage XCTest sur le
premier simulateur. La signature, les identifiants et les versions de
l'application et du widget ont été vérifiés. L'IPA téléchargée porte le
SHA-256 `477a561960764eb5f0c9a90dcc058bfe42afed63beebcf403cb6212eb0d6e9a3`.

Le patch Shorebird cible uniquement Android `1.0.27+31`. iOS utilise un
nouveau build App Store. Les vidéos précédentes restent des démonstrations
des builds Android 31 et iOS 35 ; elles ne montrent pas un déplacement réel
ni ce nouveau correctif au démarrage.

Les reçus et journaux privés restent dans le répertoire ignoré
`release-artifacts/startup-20260927/`.
