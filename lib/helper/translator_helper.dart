const List<String> _localizedDigitFamilies = [
  '٠١٢٣٤٥٦٧٨٩',
  '۰۱۲۳۴۵۶۷۸۹',
  '০১২৩৪৫৬৭৮৯',
  '०१२३४५६७८९',
  '๐๑๒๓๔๕๖๗๘๙',
];

/// Keeps all interface numbers readable as the western digits 0–9.
///
/// Quran text is not passed through this helper, so its original verse
/// numbering remains unchanged.
String translateText(String text) {
  var normalizedText = text;

  for (final digitFamily in _localizedDigitFamilies) {
    for (var digit = 0; digit <= 9; digit++) {
      normalizedText = normalizedText.replaceAll(
        digitFamily[digit],
        digit.toString(),
      );
    }
  }

  return normalizedText;
}
