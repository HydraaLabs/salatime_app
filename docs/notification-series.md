# Activer ou désactiver une série de notifications

Chaque écran « Avant l’adhan », « À l’adhan », « Après l’adhan » et
« Autres notifications » propose un interrupteur portant le nom de sa catégorie :
« Désactiver l’avant athan », « Désactiver l’athan », « Désactiver l’après athan »
ou « Désactiver les autres notifications ». Une catégorie coupée affiche
l’action inverse « Activer… ».
Il apparaît aussi lorsque ces écrans sont ouverts pendant la première configuration.

- La désactivation coupe tous les éléments de la catégorie, y compris le lever
  du soleil ou Joumou’a quand ils étaient activés, et conserve sons et délais.
- La réactivation des prières laisse le lever du soleil sur son choix actuel :
  il reste à activer individuellement. Dans les autres notifications, seuls les
  rappels visibles sont activés, sans recréer l’ancien doublon lundi/jeudi.
- Les autres catégories sont conservées. Chaque élément reste modifiable
  individuellement ; l’interrupteur de série reflète la présence d’au moins un
  élément activé, sans ajouter un second état global caché.
- Une seule écriture locale sérialisée et une seule demande de reprogrammation
  sont effectuées. La programmation continue en arrière-plan et la synchronisation
  cloud conserve son délai de 60 secondes après le dernier changement.
- Un échec d’écriture recharge les valeurs persistées avant d’afficher l’erreur,
  afin de ne pas présenter une désactivation qui n’a pas été enregistrée.

Validation : 116 tests ciblés réussis (écrans, persistance, restauration cloud,
annulation sélective des alarmes, concurrence et échecs de stockage), analyse
Flutter sans anomalie. Affichage vérifié à 320 px avec texte 200 %, français
et arabe, thèmes clair et sombre. Huit libellés traduits dans les dix langues. Après la retouche des libellés,
les 22 tests d’écran passent à nouveau, ainsi que l’analyse Flutter.

APK de test compilé avec Flutter 3.41.8 standard :
`/home/hemiad/Downloads/SalaTime-test-notifications-1.0.18-21.apk`.
Package `net.salatime.app.preview`, version `1.0.18+21`, signature debug
compatible avec le client Google Preview. SHA-256 :
`6e17f747b2851e3fcb28a7bb09c3e82ce1f64482ad63576539a2903a51efad55`.

La modification sera distribuée dans la version 1.0.19+22 après autorisation
de publication ; elle n’est pas incluse dans la précédente version 1.0.18.
Les preuves de publication sont consignées dans `release-1.0.19.md`. Le Samsung s’est déconnecté pendant
la préparation ; cet APK attend sa reconnexion pour installation et contrôle.
