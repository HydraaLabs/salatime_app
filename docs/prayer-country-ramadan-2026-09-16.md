# Sélection par pays et Isha pendant Ramadan

Ajouts demandés après l'[audit Moatheni](moatheni-calculation-alignment-2026-09-16.md), en complément de la [fenêtre Android de trois jours](prayer-three-day-window-2026-09-16.md). Aucun changement de design ni publication.

## Sélection automatique

Le pays provient du lieu géographique choisi ou de la position enregistrée. Le pays de la langue de l'interface n'est jamais une source de localisation. Le pays géographique reste sur l'appareil et est associé aux coordonnées correspondantes.

Le mode automatique utilise les identifiants de calcul SalaTime, avec priorité aux méthodes régionales déjà proposées : Maroc 21, France 12, Algérie 19, Tunisie 18, Malaisie 17, Indonésie 20, Jordanie 23, Portugal 22, Russie 14 et Iran 7. Les autres correspondances communes suivent la référence : Émirats 16, Égypte 5, Koweït 9, Libye/Arabie saoudite 4, Pakistan 1, Qatar 10, Singapour 11, Turquie 13 et Canada/Mexique/États-Unis 2. Pour les autres pays reconnus, la proposition est Moonsighting Committee 15.

Cette sélection est une convention proposée et reste modifiable. Une méthode déjà enregistrée est conservée lors de la migration ; l'utilisateur peut activer le mode automatique. Une nouvelle installation peut utiliser le mode automatique. Sans pays disponible, la méthode actuelle reste utilisée. Choisir explicitement une méthode désactive le choix automatique. L'école Hanafi et les corrections personnelles restent indépendantes.

Si une ancienne ville a des coordonnées mais pas de pays enregistré, l'activation explicite tente un géocodage inverse borné à cinq secondes, sans demander de nouvelle position GPS ni permission. Le résultat est conservé avec les coordonnées. Aucun géocodage n'est effectué pour chaque journée de prière. La méthode automatique effective est stockée séparément du choix manuel synchronisé : changer de pays ne remplace pas la méthode manuelle d'un autre appareil.

Les calendriers publiés manuels demeurent prioritaires : une préférence de calcul n'en réécrit pas les horaires.

## Isha pendant Ramadan

Un réglage facultatif propose la méthode habituelle, 90 minutes ou 120 minutes après Maghrib. Le défaut conserve la méthode. Le réglage fixe s'applique uniquement aux nuits de Ramadan : la veille du premier jour est incluse, et la veille de l'Aïd est exclue. Le calendrier hégirien de SalaTime et sa correction de −2 à +2 jours déterminent ces nuits ; il ne s'agit pas d'une détection d'observation lunaire.

Le calcul part du Maghrib de la méthode, ajoute sa correction personnelle et l'intervalle choisi. La correction personnelle d'Isha est ensuite appliquée une seule fois par le parcours existant. Le retour hors Ramadan est automatique. Les calculs affichés, partagés, les widgets et les alarmes utilisent le même résultat. Les grands décalages et les passages de minuit conservent explicitement le jour d'Isha.

Le réglage observé dans Moatheni remplaçait Isha sans condition de mois dans le chemin analysé. Ici, l'intitulé et le comportement sont volontairement limités à Ramadan. Le moteur public Adhan documente notamment l'ajustement de 30 minutes pour Umm Al-Qura pendant Ramadan, mais cet ajout ne l'impose pas aux utilisateurs : [documentation Adhan Kotlin](https://github.com/batoulapps/adhan-kotlin#calculation-parameters).

Les nouveaux réglages sont persistés localement. Aucun nouveau champ n'est envoyé au serveur de synchronisation dans cette tranche.

## Validation

- **590 tests Flutter réussis** et analyse sans problème, dont 39 tests ciblés de sélection par pays, 40 tests ciblés d'intégration Ramadan/calcul/affichage/partage et deux tests du nouveau réglage. La suite finale couvre aussi les cas Ramadan ajoutés ensuite.
- **216 tests Android réussis**, aucune erreur ni échec.
- APK **SalaTime Test** construit et installé sur le Samsung SM-S901U, Android 12, avec les données existantes conservées. La méthode manuelle enregistrée et le réglage Ramadan par défaut sont préservés ; l'installation n'active pas ces préférences à la place de l'utilisateur.
- La réception d'une alarme à froid et en veille est confirmée sur l'appareil. Les détails, le hash de l'APK et les limites de l'essai sont consignés dans la [validation de la fenêtre de trois jours](prayer-three-day-window-2026-09-16.md#validation).

Les cas de changement de pays et de nuits de Ramadan sont vérifiés par les tests automatisés ; l'horloge et la localisation du Samsung n'ont pas été modifiées pour simuler ces situations.
