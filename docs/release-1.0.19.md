# SalaTime Android 1.0.19+22

Package de production : `net.salatime.app`.

## Modification

Les écrans Avant, À l’adhan, Après et Autres notifications proposent chacun
une commande pour activer ou désactiver leur série en un geste. Les libellés
mentionnent la catégorie, par exemple « Désactiver l’avant athan » et
« Désactiver l’après athan » ; l’action inverse apparaît après désactivation.
Les commandes sont disponibles aussi pendant la première configuration.

La désactivation conserve sons et délais et annule uniquement les alarmes
concernées. Une seule écriture locale est effectuée ; la reprogrammation reste
en arrière-plan et la sauvegarde cloud intervient une minute après le dernier
changement. Le lever du soleil reste à activer individuellement, et le rappel
combiné lundi/jeudi retiré ne peut pas être réactivé par la commande globale.
Les échecs de persistance rechargent le stockage avant d’afficher une erreur.

Les huit nouveaux libellés sont traduits dans les dix langues. La langue système
est déjà utilisée au premier lancement lorsqu’elle est prise en charge ; un
choix explicite enregistré reste prioritaire. Cette règle n’a pas été modifiée.

## Préparation de publication

Préflight distant : Google Play production 1.0.18/code 21, code 22 libre ;
Shorebird Android dernière release active 826813/1.0.18+21, version 1.0.19+22 libre.
L’édition Play d’inspection a été supprimée (HTTP204). SDK release épinglé
Shorebird Flutter 3.41.6, identique à la release précédente. Aucun code Android
natif ni backend modifié. Publication explicitement demandée par l’utilisateur.

La version debug du correctif a été compilée avec Flutter 3.41.8 standard.
Le Samsung s’est déconnecté avant l’installation de ce dernier correctif ;
les tests automatisés ne constituent pas une validation physique du correctif.

## Validation du code publié

Les 116 tests ciblés passent avec le SDK release Flutter 3.41.6 : écrans,
persistance, reprogrammation des alarmes et synchronisation cloud. L’analyse
Flutter globale ne signale aucune anomalie. Les 22 tests d’écran et les captures
320 px/texte 200 % avaient aussi été contrôlés sur le SDK de test 3.41.8.
Aucun test natif n’a été relancé, le code Android natif restant inchangé.
