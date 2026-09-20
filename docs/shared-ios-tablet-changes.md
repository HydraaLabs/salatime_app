# Shared iOS and Android tablet changes

The home prayer bell controls the before, adhan and after phases of the selected
prayer together. A bell remains active while any of those phases is enabled.
Toggling it preserves each phase's sound and delay and requests a schedule
refresh. Friday's bell controls Jumuah separately from the other days' Dhuhr.

Friday's default iqama sound is `moatheni_after_prayer_jumaa`. The corresponding
MP3 and iOS AIFF are already bundled. A one-time local migration replaces the old
stored `moatheni_short_sound` value for Friday's after phase without enabling
that phase or changing its delay. Other sounds, silence and imported personal
sounds are retained. The old storage format cannot distinguish a deliberately
selected beep from the identical old default; the legacy value is upgraded once.
An explicit beep selection after the migration is preserved.

Phone navigation remains at the bottom. Windows at least 600 logical pixels wide
and 480 high use a navigation rail. The home dashboard uses two columns when its
content is at least 840 logical pixels wide. Page state survives resizing between
phone and tablet layouts. These shared layouts also apply to iPad; the project
already targets both iPhone and iPad and supports their orientations.

Regression coverage checks both Android and iOS navigation variants, iPhone
notch/home-indicator insets, theme changes, prayer settings persistence, the
sound migration, and failed preference writes. The iOS verification workflow
compiles the simulator and unsigned device app, runs native sound/widget tests,
and captures launch on iPhone and iPad simulators. This workflow does not upload
a build to App Store Connect.

Android store assets and emulated-device validation are documented in
[Android tablets](android-tablets.md). Physical-device testing remains separate
from widget tests and simulator verification.
