# Adhan Dart, SalaTime rounding patch

Vendored from `adhan` **2.0.0+1** by Riajul Islam:
https://github.com/iamriajul/adhan-dart

The original MIT license is preserved in `LICENSE`. This directory contains
the upstream library with a small, maintained patch; no code from the reference
application is included.

Local changes:

- Add `Rounding.nearest` (unchanged default) and `Rounding.up` to calculation
  parameters and apply the selected rule to the unrounded final prayer instants.
- Use `Rounding.up` in the existing Singapore calculation preset.
- Extend the Dart SDK upper bound to Dart 3 and omit unused upstream test-only
  dependencies from this vendored package.
- Scope style lint exceptions to the vendored code so that upstream public
  identifiers and source structure do not need unrelated changes.

SalaTime uses upward rounding for Singapore so that seconds below 30 are not
lost by an earlier nearest-minute rounding step. Other presets retain their
existing rounding. The app-level tests in `test/helper/adhan_rounding_test.dart`
cover exact-minute boundaries, seconds below/above 30, and date rollover.

When updating upstream, retain these tests and replace this vendor patch once
an upstream version supports the same configurable rounding behavior.
