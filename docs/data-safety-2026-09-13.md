# Déclaration des données Google Play — 13 septembre 2026

La déclaration de `net.salatime.app` a été acceptée par l’API Publisher
`applications.dataSafety` (HTTP204). La propagation publique reste soumise
à Google. Le premier modèle public de Google omettait les nouvelles questions
de création/suppression de compte ; cet essai a été refusé HTTP400, puis
remplacé par la déclaration complète acceptée, sans perte d’état validé.

Le CSV versionné contient les782réponses envoyées, avec fins de lignes LF
normalisées et espaces de fin de libellé retirés pour Git. Le CSV envoyé avait des fins de lignes CRLF.

- SHA256 CSV envoyé : `3c85bf9d8e5d0fe95f440a7ac7f53c0a8ade4acd9203586db8ef9baf47dd86ac`.
- SHA256 fichier normalisé : `c56520828cb3da675415dbc5cf782379114234b932e6233a5472f5c7b45e46ea`.

## Périmètre audité

14 catégories : nom, e-mail, identifiant de compte, choix/pratiques religieuses,
localisation approximative et précise, messages IA, interactions de navigation,
recherche de ville, contenu du générateur IA, autres actions/préférences et
lectures, plantages, diagnostics, identifiants d’installation et IP.

Comptes et lectures sont facultatifs. Les diagnostics Sentry et la mesure
IP/OS/GeoIP de l’API de paramètres existent aussi sans compte. L’identifiant
Sentry est aléatoire ; aucun Advertising ID ni SDK publicitaire n’a été trouvé.
Les transferts Sentry et Mailgun correspondent à des prestataires de diagnostic
et d’e-mails transactionnels. Les transferts fonctionnels à OSM/Nominatim/
Overpass, GeoIP et 1min.ai sont déclarés dans les catégories pertinentes.
Aucun partage de clics/gestes n’a été déclaré faute de flux démontré.

Les fichiers audio personnels, chemins locaux, permissions, recherches locales
du Coran, signets et lectures invitées ne sont pas exportés par ces services.
Aucune finalité de publicité n’est déclarée. L’engagement Families déjà présent
sur la fiche a été conservé ; aucun audit MASA ou badge UPI n’est revendiqué.

Le trajet application→SalaTime utilise HTTPS. Le pilote GeoIP effectif du
serveur (IpApi, avec IpInfo/GeoPlugin en fallback) transmet encore des IP en
HTTP : ne pas présenter tous les transferts comme chiffrés. Ce constat ne
signifie pas que les comptes sont envoyés en HTTP. La correction de ce flux
serveur n’est pas incluse dans la release mobile.

## Comptes et suppression

Création par e-mail/mot de passe et OAuth. Les deux champs de suppression
pointent vers https://salatime.net/privacy-policy#delete-account, relu en
HTTP200 : demande de suppression de compte OU de données seules, en quatre
langues, via `contact@salatime.net`, sans mot de passe/code et sans obligation
de réinstaller l’application. Suppression du compte depuis l’app également
présente. La demande n’affirme pas la suppression instantanée de tous les
journaux, sauvegardes ou enregistrements techniques indépendants du compte.

## Sources et vérification

- https://developers.google.com/android-publisher/api-ref/rest/v3/applications/dataSafety
- https://support.google.com/googleplay/android-developer/answer/10787469
- https://support.google.com/googleplay/android-developer/answer/13327111
- https://docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected/
- https://osmfoundation.org/wiki/Privacy_Policy
- https://ip-api.com/docs/legal
- https://1min.ai/privacy

Identifiants des champs modernes corroborés par le code source du générateur
Fastlane, puis acceptés par l’API Google :
https://github.com/owenbean400/fastlane-plugin-google_data_safety/blob/main/lib/fastlane/plugin/google_data_safety/helper/prompt_create_data_safety_csv_helper.rb

Aucun contenu de compte, lecture réelle, secret ou appel IA facturable n’a été
utilisé pour cet inventaire. Les preuves détaillées d’exécution restent hors Git.
