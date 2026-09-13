# SalaTime Android 1.0.18+21

Application de production : `net.salatime.app`.

## Contenu

- Adhan respectant le mode silencieux/vibreur avant et pendant la lecture.
  Arrêt avec les boutons de volume et les transitions de veille/réveil ;
  bouton Arrêter de la notification conservé. En arrière-plan, l'arrêt par
  volume nécessite un changement effectif de valeur. Les détails Android et
  la limite aux volumes extrêmes sont dans `adhan-silent-and-side-buttons.md`.
- Athkar cochés et progression de lecture du Coran enregistrés localement,
  avec historique et statistiques. Synchronisation sur le compte SalaTime
  une minute après le dernier changement, reprise hors ligne et isolation
  des données par compte. Les lectures ne sont pas cochées à l'ouverture.
- Traductions publiées du Coran dans les dix langues de l'application, suivies
  automatiquement et disponibles hors ligne. Sources QuranEnc, traducteurs,
  versions et notes conservés ; français Muhammad Hamidullah. L'arabe utilise
  le tafsir Al-Muyassar. Aucun texte coranique réécrit ou traduit manuellement.
- Invitation neutre à donner un avis Google Play après sept jours et trois
  jours d'utilisation. Report de trente jours, refus définitif et arrêt des
  relances après ouverture de la fiche. Aucun filtrage selon la satisfaction.
- Navigation des sourates adaptée aux petits écrans et aux libellés longs ;
  source de traduction et diagnostic des alarmes clarifiés.

## Préparation

Le code de version 21 est libre dans l'API Google Play ; la dernière version
Shorebird Android relue avant publication est 1.0.16+19 (release 826646).
La compilation utilise le SDK Shorebird Flutter 3.41.6 déjà validé sur la
version précédente, avec les architectures ARM32, ARM64 et x86_64.

Les nouvelles commandes d'arrêt de l'adhan sont natives Android. Elles
nécessitent un nouvel APK/AAB et ne sont pas distribuables par un patch Dart.
Le Samsung n'est pas connecté lors de cette publication ; la vérification
physique du dernier correctif n'est pas revendiquée.

## Validation avant publication

- 491 tests Flutter passent avec le SDK épinglé 3.41.6 ; analyse globale sans
  anomalie et `git diff --check` propre.
- 152 tests Android natifs passent, dont les régressions silencieux/vibreur,
  boutons latéraux et cycle de vie du lecteur.
- Vérification hors ligne des 10 éditions QuranEnc : 114 sourates et 6 236
  versets par édition, empreintes identiques au manifeste.
- API des lectures : 43 tests et 627 assertions côté Laravel ; code du
  serveur relu et identique au commit web publié
  `f5b875a7a33d037bef4a4a027db20558c9a5eead`.

## Retouche de présentation

Le suivi des lectures commence directement par la date et les statistiques.
Le bloc d’état cloud et le bouton « Synchroniser maintenant » sont retirés.
Le service de sauvegarde automatique est inchangé : sauvegarde locale immédiate,
synchronisation une minute après le dernier changement, reprise hors ligne.
La release Shorebird intermédiaire 1.0.17+20 n’a pas été envoyée sur Google Play.

La retouche de synchronisation silencieuse passe les 34 tests ciblés
(écran et service de lecture, y compris les sauvegardes différées).

## Canaux vérifiés le 13 septembre 2026

- Source compilée : `730c8263afbb97c49ccb9bd6d76ecf46b9ac425f`, poussée et
  relue sur `appfolder/salatime_app` / `main`.
- Shorebird : release **826813**, version **1.0.18+21**, Android **active**,
  artefact AAB **3666314** téléchargé et vérifié intégralement.
- Google Play, API Publisher : upload du code **21**, édition validée puis
  validée définitivement ; nouvelle édition de lecture confirmant la production
  **1.0.18**, `status: completed`, même empreinte AAB. Les autres canaux sont
  inchangés et l’édition de contrôle a été supprimée (HTTP204).
- Ce statut API confirme la soumission de production ; la disponibilité publique
  immédiate ou la réception de la mise à jour sur Samsung ne sont pas revendiquées.

### Fichiers signés

AAB final : **143307402** octets.
SHA-256 final :
`b838f18bd1ccbd13b514c81239725f2df33c768a5ebb5872b9845c5cb9293ab3`.

APK universel issu de ce même AAB : **166903784** octets.
SHA-256 :
`14f1e29e16dd4862e297046b6c3f33dc48e889f35c7f89fafa5f48ee37b78423`.

Package `net.salatime.app`, version 21 / 1.0.18, non débogable,
Android minimum 24 / cible 36, ARM32/ARM64/x86_64. Les 68 sons, le catalogue
Athkar et les 1141 JSON des traductions sont identiques aux sources. Les
commandes natives d’arrêt de l’adhan sont présentes. Certificat APK local
SHA-1 `00:84:E8:31:16:A0:5D:07:A9:37:0C:66:67:81:F3:05:BE:87:AA:70`.

Installation web contrôlée : archive versionnée puis deux alias,
sauvegarde privée et vérification de 6 anciens chemins conservés.
Trois téléchargements HTTPS intégraux vérifiés (HTTP200, type APK, taille et
empreinte identiques ; cache Cloudflare BYPASS) :

- https://salatime.net/dl/SalaTime-1.0.18-21.apk
- https://salatime.net/dl/salatime.apk
- https://salatime.net/app-release.apk

Le Samsung est toujours absent d’ADB au contrôle final. Aucune installation
sur le téléphone ni validation physique de cette version n’est revendiquée.

## Vérification dans la Console Google Play

La Console affiche explicitement la production **1.0.18** dans les modifications
« En cours d’examen », avec publication gérée désactivée. Les vérifications
automatiques Google précèdent la diffusion. Le statut API `completed` ne signifie
donc pas que cette nouvelle version est déjà disponible pour tous.

La déclaration des données précédente indiquait « aucune collecte » malgré les
comptes et la synchronisation. Un inventaire des flux est préparé dans les
métadonnées Play ; comptes, préférences, lectures et diagnostics y sont déclarés.
Le transfert GeoIP du serveur vers le pilote IpApi utilise encore HTTP en
production (pilote et protocole relus sans appel GeoIP ni données utilisateur).
Aucune affirmation de chiffrement de tous les trajets n’est faite. Le trajet
application vers SalaTime utilise HTTPS.

La déclaration Data Safety complète a été acceptée (HTTP204) puis relue dans
la Console : collecte activée, compte e-mail/mot de passe et OAuth, deux liens
de demande de suppression corrects. Voir `data-safety-2026-09-13.md` et le CSV
versionné. Aucune modification du ciblage d’âge ou de l’engagement Families.

Backend source final : `9dbafe63945aa75862efd9a2b292734cd5ce3d12`,
poussé et relu sur origin/main. Les notices de confidentialité et la demande
externe de suppression sont accessibles en EN/FR/AR/ES ; les liens e-mail
sont lisibles sans JavaScript. Contrôles HTTP et hashes des six fichiers
conformes ; 22 tests / 551 assertions. Aucun compte supprimé, aucun e-mail
envoyé et aucun changement d’environnement, SMTP ou de configuration globale.

## Déclarations Play complémentaires et démonstration audio

La déclaration du service `FOREGROUND_SERVICE_MEDIA_PLAYBACK` est enregistrée
pour « Lecture de contenus multimédias ». Une capture continue de la version
signée 1.0.18+21 sur un émulateur Android API35 montre le lecteur du Coran,
la sortie de l’application et les commandes de la notification : pause à
49,21 s, reprise à 58,87 s, arrêt à 67,78 s. Android confirme les états
PAUSED/PLAYING/NONE ; après arrêt, la notification disparaît et AudioService
n’est plus au premier plan. L’audio interne devient silencieux pendant les
pauses et après l’arrêt. Cela ne constitue pas une validation physique Samsung.

Vidéo publique de 84,109 s, 7 691 676 octets, H.264/AAC :
https://salatime.net/review/salatime-media-playback-1.0.18-657d4a27115a.mp4

SHA-256 : `657d4a27115af956eb6f838da54425dcf906c7b30946c39f930e954a0fa541fb`.
Le téléchargement HTTPS intégral correspond au fichier local. La capture
provient d’une session invitée, sans compte ni localisation personnelle ;
seul un remux MP4 faststart a été effectué, sans changer les images ou le son.
L’émulateur et le périphérique audio temporaires sont arrêtés.

L’envoi des déclarations complémentaires a été confirmé dans la Console.
Google a relancé l’examen existant pour inclure la déclaration des données ;
la déclaration du service audio accompagne ce dossier. La Console affiche
la production 1.0.18 et « Sécurité des données » dans « Modifications en cours
d’examen », ainsi que « Services de premier plan » mis à jour. Aucune
modification ne reste à envoyer manuellement. Les vérifications automatiques
Google précèdent l’examen ; la version n’est pas déclarée publiquement disponible
sur le Play Store à ce stade. La publication gérée reste désactivée.
