# SalaTime 1.0.26 — décompte des prières

Le compteur du temps écoulé laisse place à la prochaine prière au plus tard
une heure après la précédente. La priorité existante est conservée lorsque la
prochaine prière est déjà à une heure ou moins. Le décompte devient rouge
strictement sous une heure et garde sa couleur normale à exactement 60 minutes.

Cette règle est commune aux accueils classique et moderne, aux widgets Android
et iOS et au compteur de notification Android. Les actualisations natives
suivent les nouveaux seuils. Le calcul des horaires et l'activation des adhans
ne sont pas modifiés.

## Vérifications avant publication

- 638 tests Flutter réussis avec Flutter 3.41.8 ; analyse sans anomalie.
- 42 tests Android ciblés réussis : 13 widgets et 29 notifications.
- Régressions sur les seuils stricts, le basculement automatique en thèmes
  clair/sombre, les prières rapprochées et le changement de jour.
- Les tests natifs iOS ont été adaptés et doivent être exécutés par le build
  signé sur macOS avant l'envoi à Apple.

Publication demandée le 21 septembre 2026 : Android 1.0.26 (30) et iOS 1.0.26
(33). Les preuves de compilation, d'envoi et de relecture des stores seront
ajoutées après vérification. Les captures et le dossier de revue existants sont
conservés.
