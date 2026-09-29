/// Search-only folding: never changes the names displayed or played.
String normalizeCatalogSearch(String input) {
  var text = input.toLowerCase();
  const groups = {
    'a': 'àáâãäåāăą',
    'c': 'çćĉċč',
    'd': 'ďđ',
    'e': 'èéêëēĕėęě',
    'g': 'ĝğġģ',
    'h': 'ĥħ',
    'i': 'ìíîïĩīĭįıİ',
    'j': 'ĵ',
    'k': 'ķ',
    'l': 'ĺļľŀł',
    'n': 'ñńņň',
    'o': 'òóôõöøōŏő',
    'r': 'ŕŗř',
    's': 'śŝşšș',
    't': 'ţťŧț',
    'u': 'ùúûüũūŭůűų',
    'w': 'ŵ',
    'y': 'ýÿŷ',
    'z': 'źżž',
    'ا': 'أإآٱ',
    'و': 'ؤ',
    'ي': 'ئىی',
    'ك': 'ک',
    'ه': 'ةۀ',
  };
  for (final entry in groups.entries) {
    for (final rune in entry.value.runes) {
      text = text.replaceAll(String.fromCharCode(rune), entry.key);
    }
  }
  text = text.replaceAll('œ', 'oe').replaceAll('æ', 'ae');
  for (var digit = 0; digit < 10; digit++) {
    text = text
        .replaceAll(String.fromCharCode(0x0660 + digit), '$digit')
        .replaceAll(String.fromCharCode(0x06f0 + digit), '$digit');
  }
  return text
      .replaceAll(_searchMarks, '')
      .replaceAll(_searchSeparators, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

final _searchMarks = RegExp(
  r'[\u0300-\u036f\u0610-\u061a\u0640\u064b-\u065f\u0670'
  r'\u06d6-\u06ed\u08d3-\u08ff\u200c-\u200f\u202a-\u202e\u2066-\u2069]',
);
final _searchSeparators = RegExp(r'''[-‐‑‒–—_'’‘`.,:;!?/()\[\]{}،؛؟«»"“”]''');

/// Every query word can match any of the item's localized/Arabic aliases.
/// Hyphenated transliterations also match a spelling without separators.
bool matchesCatalogSearch(String query, Iterable<String?> fields) {
  final normalized = normalizeCatalogSearch(query);
  if (normalized.isEmpty) return true;
  final names = fields.whereType<String>().map(normalizeCatalogSearch).toList();
  return normalized
      .split(' ')
      .every(
        (word) => names.any(
          (name) =>
              name.contains(word) || name.replaceAll(' ', '').contains(word),
        ),
      );
}
