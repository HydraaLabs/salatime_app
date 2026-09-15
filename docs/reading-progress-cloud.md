# Suivi des lectures Athkar et Coran

Ajout du 13 septembre 2026, postérieur à la soumission Play/Shorebird 1.0.16+19.
Les artefacts de production décrits dans `release-1.0.16.md` ne contiennent pas
ce nouveau suivi. L'API a été activée indépendamment de la livraison mobile.

## Comportement

- Les 218 invocations disposent d'une confirmation de lecture quotidienne.
  Cocher termine les répétitions de l'invocation ; décocher les remet à zéro.
  Les incréments intermédiaires et les confirmations sont sauvegardés.
- Le Coran permet de confirmer les versets d'une page dans la vue arabe, ou un
  verset à la fois dans la vue avec traduction, en ligne comme hors ligne.
  Une case partielle indique que certains versets de la page sont déjà lus.
- Ouvrir ou faire défiler une sourate ne la marque plus comme lue. Les cartes
  de l'accueil comptent les sourates dont tous les versets ont été confirmés
  le jour concerné. Les anciens compteurs basés sur les ouvertures ne sont pas
  importés comme des confirmations de lecture.
- L'icône de statistiques des lecteurs Athkar et Coran ouvre le suivi : date
  choisie, historique quotidien, graphique sur sept jours, invocations
  terminées, versets et sourates lus, versets distincts parmi 6 236 et série
  de jours actifs. Le changement de jour conserve l'historique.
- Les cases et statistiques réagissent immédiatement. Une page est enregistrée
  dans une seule écriture locale. L'envoi automatique attend 60 secondes après
  le dernier changement ; ouvrir les statistiques respecte aussi ce délai.
  La synchronisation reste invisible dans le suivi des lectures.
- Hors ligne, les opérations restent persistées sur le téléphone. Les essais
  automatiques reprennent lorsque l'application est active et le réseau
  disponible. Si Android suspend l'application, le cloud peut donc être mis
  à jour au prochain retour dans l'application plutôt qu'exactement à 60 s.
- Sans compte, les lectures restent locales. À la connexion, elles sont
  transférées au compte et fusionnées par élément et date avec le maximum des
  compteurs, sans additionner deux fois une lecture. Le cache invité des anciennes
  versions est aussi récupéré au démarrage si le compte est déjà connecté.
- Le destinataire du transfert est enregistré avant la copie ; les lectures,
  opérations à envoyer et reçu sont ensuite sauvegardés ensemble dans le cache
  du compte. Le cache invité n'est vidé qu'après cette sauvegarde. Une interruption
  reprend le même transfert sans doublons ni copie vers un autre compte.

## Synchronisation

`ReadingProgressService` conserve un document local par serveur et par profil,
avec les lectures, le curseur de téléchargement et les opérations à envoyer.
Le document ne contient ni jeton ni profil personnel. Les identifiants Quran
sont des références canoniques `sourate:verset`, indépendantes des traductions.

L'API authentifiée utilise `GET /api/mobile/reading-progress` (pages de 500) et
`POST /api/mobile/reading-progress/batch` (lots de 100 opérations). Chaque
opération possède un UUID immuable. Les relances ne doublent pas les lectures
et ne rejouent pas une ancienne modification déjà acceptée. Les annulations
restent synchronisées sous forme de compteurs à zéro.

Les modifications locales en attente restent affichées pendant les échanges.
Une réponse d'une ancienne session ne peut ni écraser le nouveau compte ni
le déconnecter. Un POST n'avance jamais le curseur GET, pour ne pas ignorer
les autres lectures enregistrées sur un deuxième appareil.

Pour deux nouvelles opérations concurrentes concernant la même lecture et le
même jour, la dernière reçue par le serveur prévaut. Il ne s'agit pas d'une
addition des lectures des deux appareils. Les enregistrements sont supprimés
avec le compte par les relations de base de données.

Exception pour les imports invités : `merge: true` applique le maximum sous le
verrou transactionnel du compte, sans écraser une progression cloud supérieure.
Le mode fait partie de l'identité immuable de l'opération ; une relance après
une annulation plus récente ne rétablit pas une ancienne lecture. Les opérations
ordinaires des anciennes versions gardent leur comportement (`merge: false`).

### Livraison du correctif de fusion du 14 septembre 2026

Déployer le serveur avant le nouveau client : appliquer la migration
`2026_09_14_020000_add_merge_to_mobile_reading_operations.php`, puis le contrôleur
`ReadingProgressController.php` et les quatre traductions `reading_privacy.php`.
La migration ajoute uniquement un booléen technique aux opérations ; elle ne
supprime aucune lecture et n'importe aucune donnée personnelle.
Un ancien serveur refuse les imports avec `merge: true` : ils restent dans la
file locale pour réessai, sans perte des statistiques, jusqu'à sa mise à jour.

Serveur mis à jour le 14 septembre 2026 : migration confirmée, contrôleur et
traductions vérifiés par SHA256, contrôles HTTP publics réussis. Le correctif
mobile reste à livrer ; ce déploiement n'a pas modifié les APK ni publié sur les
stores. Le reçu détaillé figure dans `web/documentation/mobile-reading-progress.md`.

## Corrections liées au lecteur

- Les boutons de sourate précédente/suivante peuvent prendre plusieurs lignes,
  sans le débordement montré dans la capture de l'utilisateur.
- Le texte arabe hors ligne utilise la couleur du thème en mode sombre.
- Deux anciens fichiers hors ligne dupliquaient une autre sourate :
  `ar/s0087.json` contenait la 86 et `sp/s0092.json` contenait la 91.
  Ils ont été remplacés par les réponses de notre API pour 87 (traducteur 4)
  et 92 (traducteur 3), après concordance du texte arabe avec le catalogue
  anglais existant. Les quatre catalogues de 114 sourates contiennent chacun
  exactement les 6 236 clés canoniques, sans doublon.

## Validation et activation du serveur

- 426 tests Flutter réussis avec le SDK de publication Flutter 3.41.6.
- Analyse Flutter globale sans anomalie.
- Cas couverts : sauvegarde locale et reprise, cases et annulation, pages
  partielles, textes agrandis sur 320 px, français/arabe et thèmes clair/sombre,
  changement de jour/compte, conflits, reprise des lots, pagination, erreurs de
  stockage, UUID stables et délai de 60 secondes.
- 17 tests backend spécifiques (280 assertions), puis 46 tests lectures,
  comptes et bienvenue (618 assertions), en base SQLite isolée sans mail réel.
- API installée sur `salatime.net` : contrôleur, catalogue des clés, migration
  additive dédiée et deux routes. Migration exécutée seule avant l'activation
  des routes ; sauvegarde privée et vérification des empreintes effectuées.
- Tables, colonne de révision et catalogue relus sur le serveur ; routes
  anonymes refusées avec HTTP 401. Lecture vide vérifiée sans créer de compte,
  de jeton ou de lecture fictive. Site et configuration des comptes HTTP 200.
- La vérification entre deux appareils physiques reste distincte des tests
  de synchronisation et des contrôles HTTP/SQL réalisés ici.

Les détails du protocole sont dans le dépôt web :
`documentation/mobile-reading-progress.md`.

## Prévisualisation installée

- Application `net.salatime.app.preview`, libellé « SalaTime Test », version de
  travail 1.0.16+19 construite avec Flutter 3.41.8. Aucun nouvel artefact de
  production Play/Shorebird ni nouveau téléchargement public publié pour cet
  ajout ; le numéro de version de travail n'identifie donc pas son contenu.
- APK `SalaTime-test-lectures-cloud-1.0.16-19.apk`, 201 489 903 octets ; SHA-256
  `9d7d6ece9ef5a0c4eb3d25732f8539fefdae50a64a7587a812d642207b778143`.
- Identité du package et signature debug contrôlées ; APK installé avec `-r`
  sur le Samsung SM-S901U en conservant les données de la prévisualisation.
  L'application Play signée par Google n'a pas été remplacée.
- Le téléphone était verrouillé lors de la vérification finale : installation
  et démarrage du processus confirmés, mais pas de validation visuelle des
  nouveaux écrans sur le Samsung. Aucune lecture fictive ajoutée au compte.
- Les fichiers de langue et les deux sourates corrigées dans l'APK correspondent
  exactement aux sources vérifiées.
