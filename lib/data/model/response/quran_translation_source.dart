/// Attribution shipped with an unmodified, published QuranEnc edition.
class QuranTranslationSource {
  const QuranTranslationSource({
    required this.languageCode,
    required this.editionKey,
    required this.title,
    required this.publisher,
    required this.version,
    required this.sourceUrl,
    this.isTafsir = false,
  });

  final String languageCode;
  final String editionKey;
  final String title;
  final String publisher;
  final String version;
  final String sourceUrl;
  final bool isTafsir;

  bool get isRtl => const {'ar', 'fa', 'ur'}.contains(languageCode);

  factory QuranTranslationSource.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing translation source $key');
      }
      return value;
    }

    return QuranTranslationSource(
      languageCode: requiredText('languageCode'),
      editionKey: requiredText('editionKey'),
      title: requiredText('title'),
      publisher: requiredText('publisher'),
      version: requiredText('version'),
      sourceUrl: requiredText('sourceUrl'),
      isTafsir: json['isTafsir'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'editionKey': editionKey,
    'title': title,
    'publisher': publisher,
    'version': version,
    'sourceUrl': sourceUrl,
    'isTafsir': isTafsir,
  };
}
