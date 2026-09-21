# SalaTime iOS 1.0.25 (32) — soumission du 21 septembre 2026

La version **1.0.25 (32)** est soumise à App Review depuis le 21 septembre 2026
à **02:08:36 UTC**. L'API confirme `WAITING_FOR_REVIEW` pour la version et sa
soumission. La publication est automatique après approbation (`AFTER_APPROVAL`).
L'approbation et la disponibilité publique restent en attente.

- [App Store Connect](https://appstoreconnect.apple.com/apps/6812923710/distribution)
- [Compilation, signature et envoi](https://github.com/HydraaLabs/salatime_app/actions/runs/35549871377)
- Source : `310c6820f711e86d545e9a6059730fce061607af`, branche `main`.
- Build Apple : `af7c3d4b-e4d2-4929-8ba2-1abf09b2965a`, état `VALID`.
- Soumission : `c117bd7d-77d3-48c7-8542-ebc58693889e`.
- Version App Store : `fec07b01-c9f0-4325-9adc-b9245542fce6`.

## Changements inclus

La cloche d'une prière commande ses rappels avant, pendant et après l'adhan.
Les sons et délais enregistrés sont conservés lors de cette activation ou
désactivation. Le son par défaut de l'iqama du vendredi est corrigé, avec une
migration de l'ancienne valeur. L'interface s'adapte à l'iPad et aux fenêtres
larges. Les correctifs précédents des fuseaux horaires, widgets et notifications
sont également inclus. Voir les [changements partagés](../shared-ios-tablet-changes.md).

## Vérifications

- Analyse Flutter réussie et **636 tests Flutter** réussis avec Flutter 3.41.8.
- Compilation du simulateur et suite native `RunnerTests` réussies avec Xcode
  26.3. La suite comprend neuf tests, dont la présence et la durée des 68 sons.
- Archive et IPA signés : identifiants, versions, profils de distribution,
  App Group, Keychain, capacité Apple et retour Google contrôlés pour l'app et
  son extension WidgetKit.
- Contrôle indépendant de l'IPA récupéré : app et widget en 1.0.25 (32), prise
  en charge iPhone/iPad, iOS minimum 15.0, 68 sons identiques aux sources et
  tous inférieurs à 30 secondes (maximum mesuré : 29,001723 secondes).
- Apple confirme le transfert `COMPLETE`, le build `VALID`, aucune erreur ni
  aucun avertissement de traitement et `usesNonExemptEncryption=false`.
- Connexion du compte de démonstration vérifié, lecture du profil, des
  préférences et de la progression réussies. La session de contrôle a été
  révoquée après ces lectures.

La première tentative de compilation a expiré pendant la préparation du moteur
de tests du simulateur, avant l'exécution des tests natifs. La seconde tentative
sur un autre serveur Mac a réussi avec le même commit et le même build 32.
Aucun envoi à Apple n'avait eu lieu lors de la première tentative.

Ces contrôles ne constituent pas un nouvel essai sur iPhone physique. La vidéo
de démonstration provient de l'iPhone utilisé le 17 septembre et précède les
derniers correctifs ; cette portée est précisée dans les notes de revue.

## Dossier de revue et artefact

L'ancienne soumission de 1.0.22 (31) a été retirée après validation du nouveau
build. La fiche existante a été mise à jour en 1.0.25, le build 32 associé et les
notes adaptées, puis une nouvelle soumission a été envoyée par API. La relecture
confirme la conservation des trois langues (français, anglais, arabe), des
**36 captures iPhone/iPad**, de leur ordre et de leurs empreintes, de la vidéo
de démonstration, du contact de revue et des accès du compte de démonstration.

| Propriété | Valeur |
| --- | --- |
| Bundle app | `net.salatime.app` |
| Bundle widget | `net.salatime.app.SalaTimeWidget` |
| Taille IPA | 82 841 682 octets |
| SHA-256 IPA | `33a3fe4c9ad26b5b9f6daf691dd24f0c827c039ed860adc7b65173fc2cd8d3f5` |
| Artefact GitHub | `10618876181` |
| SHA-256 ZIP GitHub | `20e3a7d7c365e041da0d7fdf6e82bb914c43297888502d23671b3a81c71218eb` |

Le [reçu de soumission](submission-1.0.25-32.json) est versionné. L'IPA, les
rapports de signature, les deux journaux de compilation, les contrôles locaux
et les réponses Apple sont conservés hors Git dans
`release-artifacts/ios-1.0.25-32/`.
