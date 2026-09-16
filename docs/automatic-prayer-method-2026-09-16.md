# Méthode de calcul automatique par pays

Le sélecteur des méthodes propose une option automatique. Les utilisateurs avec
une méthode déjà enregistrée gardent le mode manuel ; une installation neuve
active l'option. Le choix explicite d'une méthode, même identique à celle
résolue automatiquement, désactive l'option. L'école juridique et les corrections
personnelles restent inchangées.

Le pays provient uniquement de `Placemark.isoCountryCode` (GPS/géocodage) ou de
`address.country_code` (ville Nominatim). Le pays d'interface `country_code`
n'est jamais utilisé. Le code pays et ses coordonnées restent dans les
préférences locales ; le lien exact avec les coordonnées empêche de réutiliser
un ancien pays après un déplacement ou une restauration de ville.

Les correspondances partagées avec la référence sont AE→16, EG→5, KW→9,
LY/SA→4, PK→1, QA→10, SG→11, TR→13 et CA/MX/US→2. SalaTime conserve ses
méthodes nationales supplémentaires : MA→21, FR→12, DZ→19, TN→18, MY→17,
ID→20, JO→23, PT→22, RU→14 et IR→7. Les autres pays ISO valides utilisent
Moonsighting (15). Pays absent ou invalide : dernière méthode effective
conservée, puis choix manuel sauvegardé, puis valeur historique 1.

La dernière méthode automatique utilise `prayer_calculation_auto_method_v1`.
Elle n'écrase pas `selectedCalculationMethod`, choix manuel synchronisé avec
le compte. Les nouvelles préférences ne sont pas ajoutées au contrat cloud.
Une désactivation explicite de l'auto fige la méthode affichée comme choix manuel.

Pour une ancienne ville dépourvue de pays, l'activation explicite tente un
géocodage des coordonnées déjà sauvegardées, limité à cinq secondes. Elle
ne demande ni nouvelle position GPS ni permission. Les rafraîchissements
passifs et le calcul des trente jours ne font aucun géocodage. Hors ligne,
la méthode précédente reste disponible. Choisir une ville arrête le suivi
automatique de position via le service existant.

Les calendriers publiés par une ville restent autoritaires. Pour les calculs
locaux, le contrôleur applique aussi l'option Ramadan via
`RamadanIshaSettings.enrichRequest` avant le calcul.

Validation ciblée : 39 tests helper/contrôleur/écran, dont migration,
changement de pays, cache de coordonnées, erreurs de stockage, maintien du
choix manuel cloud, fonctionnement hors ligne et affichage FR/AR à texte agrandi.
