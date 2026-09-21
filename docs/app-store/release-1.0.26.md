# SalaTime iOS 1.0.26 (33) — soumission du 21 septembre 2026

La version **1.0.26 (33)** est soumise à App Review depuis le 21 septembre 2026
à **19:13:41 UTC**. L'API confirme `WAITING_FOR_REVIEW` pour la version et sa
soumission. La publication est automatique après approbation (`AFTER_APPROVAL`).
L'approbation et la disponibilité publique restent en attente.

- [App Store Connect](https://appstoreconnect.apple.com/apps/6812923710/distribution)
- [Compilation, signature et envoi](https://github.com/HydraaLabs/salatime_app/actions/runs/35638919005)
- Source : `e0fdc0e34db8b2377483d1fa4e00c4280b68473c`, branche `main`.
- Build Apple : `8746cfd2-556e-4642-98a8-f9de616b94b0`, état `VALID`.
- Soumission : `9310cc24-6213-4e64-91fb-a3970a56930b`.
- Version App Store : `fec07b01-c9f0-4325-9adc-b9245542fce6`.

## Changements inclus

Le temps écoulé laisse place au décompte de la prochaine prière au plus tard
une heure après la précédente. La priorité existante est conservée lorsque la
prochaine prière est déjà à une heure ou moins. Le décompte devient rouge
strictement sous une heure et garde sa couleur normale à exactement 60 minutes.
L'accueil classique/moderne et le widget suivent les mêmes seuils. Le calcul
des horaires et l'activation des adhans ne sont pas modifiés.

Les changements précédents concernant les fuseaux horaires, les notifications,
le son de l'iqama du vendredi, les cloches de prière et l'interface iPad restent
inclus. Voir la [release commune Android/iOS](../release-1.0.26.md).

## Vérifications

- Analyse réussie et **638 tests Flutter** réussis avec Flutter 3.41.8 sur macOS.
- Compilation simulateur et suite native `RunnerTests` réussies avec Xcode
  26.3. Les dix méthodes couvrent notamment les seuils, minuit et la présence
  et la durée des 68 sons. La compilation réussit dès la première tentative.
- Archive et IPA signés : identifiants, versions, profils de distribution,
  App Group, Keychain, capacité Apple et retour Google contrôlés pour l'app et
  son extension WidgetKit.
- Copie récupérée par API GitHub et empreinte ZIP conforme au digest de
  l'artefact. Contrôle indépendant de l'IPA : app et widget en 1.0.26 (33),
  prise en charge iPhone/iPad, iOS minimum 15.0, 68 sons identiques aux sources
  et tous inférieurs à 30 secondes (maximum mesuré : 29,001723 secondes).
- Validation et envoi Apple réussis ; transfert `COMPLETE`, build `VALID`,
  aucune erreur ni aucun avertissement de traitement et
  `usesNonExemptEncryption=false`.
- Les fichiers de signature temporaires ont été retirés du serveur de
  compilation par l'étape de nettoyage, confirmée réussie.

Ces contrôles ne constituent pas un nouvel essai sur iPhone physique. La vidéo
de démonstration date du 17 septembre et précède les derniers correctifs ; cette
portée est précisée dans les notes de revue.

## Dossier de revue et artefact

L'ancienne soumission de 1.0.25 (32) a été retirée après validation du build 33.
La fiche existante a été mise à jour en 1.0.26, le nouveau build associé et les
notes adaptées, puis une nouvelle soumission a été envoyée par API. La relecture
confirme les trois langues (français, anglais, arabe), les **36 captures
iPhone/iPad**, leur ordre et leurs empreintes, la vidéo, le contact de revue et
les accès du compte de démonstration conservés.

| Propriété | Valeur |
| --- | --- |
| Bundle app | `net.salatime.app` |
| Bundle widget | `net.salatime.app.SalaTimeWidget` |
| Taille IPA | 82 841 684 octets |
| SHA-256 IPA | `0741c18ca0bbbd9ac5aeae360256f6b67a4d510bda06baa92d2b94d06d7dc6cb` |
| Artefact GitHub | `10658572578` |
| SHA-256 ZIP GitHub | `f7930dcaf9b072c88b13bf59403fe3dbb266bb140901b2eacbc9ee7f3345e95e` |

Le [reçu de soumission](submission-1.0.26-33.json) est versionné. L'IPA, les
rapports de signature, les journaux de compilation, les contrôles locaux et les
réponses Apple sont conservés hors Git dans `release-artifacts/ios-1.0.26-33/`.
