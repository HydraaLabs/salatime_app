# Checklist publication Play Store — SalaTime

## 1. Créer l'app dans Play Console (manuel, obligatoire)
- Aller sur https://play.google.com/console → **Créer une application**
- Nom : `SalaTime - Horaires de Prière`
- Langue par défaut : Français
- Type : Application / Gratuite
- Package name (applicationId) : **`net.salatime.app`** — déjà configuré dans le build, ne pas en choisir un autre

## 2. Upload du bundle
- Fichier : `zabi/build/app/outputs/bundle/release/app-release.aab`
- Production → Nouvelle version → importer l'AAB
- **Activer Play App Signing** (recommandé) : Google garde la clé finale, notre `upload-keystore.jks` reste la clé d'upload (récupérable en cas de perte)

## 3. Fiche du Play Store
- Titre / description courte / complète : voir `listing-fr.md` (fr-FR) et `listing-en.md` (en-US)
- Icône 512×512 : `web/public/assets/favicon/web-app-manifest-512x512.png`
- Bannière (feature graphic) 1024×500 : **à créer** (obligatoire)
- Captures d'écran téléphone : min 2 (1080×1920 ou plus) — **à fournir** (les screenshots déjà partagés : accueil, Coran, mosquées, Qibla, hadiths)
- Catégorie : **Style de vie** (Lifestyle)
- Coordonnées : email de contact + site web https://salatime.net

## 4. Contenu obligatoire avant publication
- Politique de confidentialité : **https://salatime.net/privacy-policy** (déjà en ligne)
- Questionnaire classification du contenu : tout public (PEGI 3)
- Public cible : 13+ (comportement standard)
- Déclaration permissions : localisation (mosquées, horaires), notifications (adhan)
- News app : non / COVID : non

## 5. Clé d'upload (À SAUVEGARDER !)
- Fichier : `zabi/android/upload-keystore.jks`
- Mots de passe : `zabi/android/key.properties` (gitignored — jamais commité)
- ⚠️ Sans cette clé (ou Play App Signing activé), impossible de publier des mises à jour

## 6. Publication automatisée (optionnel)
L'API Google Play Developer nécessite un **compte de service JSON**
(Google Cloud Console → APIs → Google Play Android Developer API → service account,
puis l'inviter dans Play Console avec droits "Admin").
La chaîne `33df21c9...` fournie n'est pas exploitable comme identifiant API.
Avec le JSON du compte de service, on peut automatiser via fastlane supply.
