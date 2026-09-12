# Remplacement des réglages de notifications

**Mise à jour de la réactivité :** voir [la sauvegarde et la reprogrammation en arrière-plan](notification-background-2026-09-12.md). Les valeurs par défaut ci-dessous restent valables ; les empreintes de livraison les plus récentes se trouvent dans ce nouveau bilan.

Cette modification remplace l’ancienne configuration à son global par quatre vues : avant l’adhan, à l’adhan, après l’adhan et autres notifications. Le thème SalaTime est conservé. Les mêmes vues sont accessibles dès le premier lancement.

La dernière consigne utilisateur demande aussi d’activer ce qui est actif par défaut dans Moadine. Elle remplace la consigne antérieure « avant/après désactivés ». La référence vérifiée est Moatheni 3.0.5 (63), récupérée sur le Samsung ; ses données de configuration ont été consultées pour reproduire le comportement, sans incorporer son code.

## Prières

Chacune des trois vues affiche Fajr, lever du soleil, Dohr, Joumou‘a, Asr, Maghrib et Isha. Chaque entrée possède sa propre activation et son propre son ; avant/après disposent aussi d’un délai de 0 à 120 minutes.

- Fajr, Dohr, Joumou‘a, Asr, Maghrib et Isha : activés dans les trois vues, soit 18 réglages actifs.
- Lever du soleil : désactivé dans les trois vues.
- Vendredi : Joumou‘a remplace Dohr au même horaire corrigé ; aucune double alarme.
- Les phases sont indépendantes : désactiver l’adhan ne désactive plus ses rappels avant/après.

| Prière | Avant | Après | Sons par défaut |
| --- | ---: | ---: | --- |
| Fajr | 5 min | 10 min | Sons dédiés avant / adhan / iqama Fajr |
| Lever du soleil | 5 min | 10 min | Eau / oiseau / tonalité double |
| Dohr | 5 min | 10 min | Sons dédiés avant / adhan / iqama Dohr |
| Joumou‘a | 120 min | 10 min | Avant Joumou‘a / adhan Joumou‘a / tonalité double |
| Asr | 5 min | 10 min | Sons dédiés avant / adhan / iqama Asr |
| Maghrib | 10 min | 3 min | Sons dédiés avant / adhan / iqama Maghrib |
| Isha | 5 min | 10 min | Sons dédiés avant / adhan / iqama Isha |

## Autres notifications

Les 11 cartes suivent l’ordre de Moadine. Elles sont toutes désactivées à l’installation. Le son et le délai apparaissent lorsque la carte est activée.

| Rappel | Horaire par défaut | Ressource sonore |
| --- | --- | --- |
| Alerte Fajr | 20 min avant Fajr | `moatheni_ring1` |
| Duha | 30 min avant Dohr | `moatheni_duha` |
| Invocations du matin | 30 min après Fajr | `moatheni_morning_azkar1` |
| Invocations du soir | 30 min après Asr | `moatheni_evening_azkar1` |
| Invocations du coucher | 60 min après Isha | `moatheni_sleep_azkar` |
| Jeûne du lundi | Dimanche, 60 min après Isha | `moatheni_monday_fasting` |
| Jeûne du jeudi | Mercredi, 60 min après Isha | `moatheni_thursday_fasting` |
| Jours blancs | Le 12 hégirien, 60 min après Isha | `moatheni_white_days` |
| Milieu de la nuit | 15 min avant le milieu de Maghrib → Fajr | `moatheni_midnight` |
| Dernier tiers de la nuit | 15 min avant son début | `moatheni_last_third` |
| Heure du vendredi | 40 min avant Maghrib | `moatheni_jumaa_hour` |

Fajr, Duha et le soir permettent de changer le point de référence avant/après. Les horaires tiennent compte du fuseau, des corrections de prières et du changement de date.

## Persistance et fiabilité

Les anciens sons et délais génériques sont remplacés une seule fois par les valeurs correspondantes. Les sons personnalisés et les changements effectués dans la nouvelle configuration restent conservés. Les préférences du compte comprennent maintenant les réglages par prière, les nouvelles catégories et leurs horaires.

La page se met à jour après une restauration cloud. Un choix effectué dans un sélecteur de son ou de délai ne réécrit que le champ modifié, sans écraser les autres préférences restaurées entre-temps.

Les changements recalculent les alarmes sans demander de permission lors d’une désactivation. Les nouveaux types sont reconnus par la restauration Android après redémarrage ; le lever du soleil reste exclu du compteur de prière de 90 minutes et des règles de silence des cinq prières.

La bibliothèque des 68 sons, la préécoute et l’import personnel sont conservés. L’import se trouve dans le sélecteur de son afin de ne pas encombrer chaque carte.

## Livraison

Modifications locales uniquement : aucun push, déploiement web, envoi Play ou publication Shorebird. L’application de test Android utilise `net.salatime.app.preview` et ne remplace pas l’application Play existante.


## Validation finale

- Analyse Flutter sans problème ; suite complète : **227 tests réussis**.
- Android natif : **83 tests debug réussis**, sans erreur ni échec.
- API mobile des préférences : **19 tests / 288 assertions réussis** sur SQLite en mémoire, sans base de production.
- Contrôle des 68 MP3 par SHA-256 dans les ressources et dans les deux livrables finaux : identiques au catalogue source.
- Présentation contrôlée en français et arabe, petit écran / paysage / tablette et texte agrandi.
- Synchronisation : les pages par phase et la page des autres rappels se rafraîchissent après restauration des préférences, y compris lorsqu’elles sont déjà ouvertes.

### Samsung

APK final installé dans **SalaTime Test 1.0.15+18**, en parallèle de l’application Play, sur SM-S901U / Android 12. Les quatre vues, les valeurs par défaut, la recherche de sons et les vues de délai ont été parcourues sur le téléphone.

Le test a identifié une lenteur réelle : toute la liste Android était réécrite à chaque réglage. Les alarmes identiques sont maintenant réutilisées ; seules celles qui changent sont réécrites, et la restauration native des alarmes est conservée.

Avec les préférences déjà présentes du téléphone, désactiver le rappel après Fajr a supprimé ses 27 occurrences du manifeste et du cache natif en **9,27 s**. Sa réactivation les a rétablies en **7,93 s**. État final : **393 notifications de prière + 57 rappels supplémentaires**, **450 alarmes correspondantes dans AlarmManager**, aucun échec de programmation signalé. Le rappel après Fajr est de nouveau activé avec son son et ses 10 minutes par défaut.

Les préférences préexistantes des rappels Duha, dernier tiers et vendredi ont été conservées ; elles ne changent pas les valeurs d’une nouvelle installation, dont les 11 autres rappels restent désactivés. La vérification de cette tranche couvre les réglages et la programmation ; elle ne constitue pas un essai de réception réel de chaque nouveau rappel. Les réglages temporaires de veille USB ont été rétablis et le fichier de contrôle de l’interface retiré du téléphone.

Captures de contrôle : `/tmp/salatime-notification-replacement-qa/`.

### Livrables locaux actuels

- APK installé : `/home/hemiad/Downloads/SalaTime-test-1.0.15-18.apk` — SHA-256 `64200ee7107952b2ea88e16e2788061e9bab063736ce2681a65fe0c063cff9bf`.
- AAB release : `build/app/outputs/bundle/release/app-release.aab` — SHA-256 `dc964ae80f5551b76c90cb5b7334f3d17e8cb336155f1310714e3504b7c3688a`.

Aucune publication effectuée. Ces empreintes remplacent celles du bilan de la tranche précédente.
