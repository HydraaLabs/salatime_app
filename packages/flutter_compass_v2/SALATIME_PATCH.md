# SalaTime Android patch

This package is vendored from `flutter_compass_v2` 1.0.3 so the Android
sensor callback can safely ignore non-finite rotation readings.

The upstream implementation constructs an `Azimuth` before its later `NaN`
check. Some Android sensors can briefly produce a non-finite reading, causing
an uncaught `IllegalArgumentException` instead of skipping that sample.

SalaTime's patch:

- rejects non-finite rotation-vector components before calculation;
- returns no azimuth when Android calculates a non-finite result;
- rejects both `NaN` and infinite headings before sending a Flutter event.

Upstream report: https://github.com/hemanthrajv/flutter_compass/issues/109
