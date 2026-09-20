# Correctif horaire du 20 septembre 2026

## Android — patch Shorebird publié

Le patch **1**, identifiant **664638**, est actif sur le canal **stable** de
**1.0.22+25**, release **835456**, application
`53488219-9639-4aac-87fc-72812320f340` (`net.salatime.app`).

Le code principal est poussé au commit
[`8ccc39d`](https://github.com/HydraaLabs/salatime_app/commit/8ccc39d48d04de694e76642763273e7e9b4639fb).
Le patch de production est construit depuis
[`c09f884`](https://github.com/HydraaLabs/salatime_app/commit/c09f884d0b6d284413a641fb51d3f1d6f7c02b35),
sur la branche `hotfix/timezone-1.0.22`, à partir du commit de la release
`2e9e9d6e9674a20b5c3e167857b6ee4f9e12e7f6`.
Cette adaptation conserve intégralement les sources natives, ressources et
dépendances de la version installée. Le patch porte sur la résolution des
fuseaux, les calculs, les widgets et la reprogrammation des rappels.
Voir [le fonctionnement du correctif](timezones.md).

Validation sur Shorebird Flutter **3.41.6**, révision
`76ca3dff01cc7c5e6978e6b51e442777c6930419` : analyse sans problème,
**599 tests réussis**, vérification `--dry-run` réussie, puis publication
sans autoriser de différences natives ou de ressources.

L'API de contrôle utilisée par les applications confirme `patch_available=true`
et `number=1` pour les trois architectures. Les deltas téléchargés sont identiques
aux fichiers produits localement et les empreintes des bibliothèques cibles
correspondent à celles annoncées par Shorebird.

| Architecture | Taille du delta | SHA-256 de la bibliothèque cible |
| --- | ---: | --- |
| aarch64 | 1 486 665 octets | `0f285c150ea7cd37ebc54fc1ddc7a4caa0f06f84d16d02ca976b699b22179fd1` |
| arm | 1 478 933 octets | `756896ebafd32b172a0f659d13b5485c37fa1bb83fa9fe781bf9bf4c3c3fc51a` |
| x86_64 | 1 323 908 octets | `38b053701e04f98f1bcefa6fe873336b01686d5c2f82980927d20ea1ad12bd6f` |

Reçus locaux : `release-artifacts/timezones-2026-09-20/shorebird-published.json`
et les journaux `shorebird-*.log`. Ils ne contiennent pas de clé de publication.
La disponibilité du patch ne prouve pas son installation sur un appareil donné.
Il cible 1.0.22+25 ; les anciennes releases ne reçoivent pas automatiquement
les patches d'une autre version.

Avec la mise à jour automatique de Shorebird, l'application recherche le patch
à l'ouverture et utilise le code téléchargé lors d'un lancement ultérieur.
Source : [fonctionnement de Code Push](https://docs.shorebird.dev/code-push/).

## iOS

La lecture Shorebird du 20 septembre ne retourne aucune release iOS pour cette
application. Le build App Store 30 a été produit avec Flutter standard ; un
patch Shorebird ne peut donc pas lui être appliqué. La correction iOS passe par
un nouveau build signé et une nouvelle soumission à App Review.
