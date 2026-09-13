import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/data/model/response/quran_translation_source.dart';

/// Converts presentation markup without rewriting the published wording.
/// Original translation and note strings remain unchanged in the model.
String quranTranslationPlainText(String source) {
  var text = source.replaceAll(
    RegExp(r'<br\s*/?>', caseSensitive: false),
    '\n',
  );
  text = text.replaceAll(
    RegExp(r'</(?:p|div|li)\s*>', caseSensitive: false),
    '\n',
  );
  text = text.replaceAll(
    RegExp(
      r'</?(?:p|div|span|sup|sub|b|strong|i|em|a|ul|ol|li|u|small)(?:\s[^>]*)?>',
      caseSensitive: false,
    ),
    '',
  );
  const entities = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': '\u00a0',
  };
  return text.replaceAllMapped(
    RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos|nbsp);'),
    (match) {
      final entity = match.group(1)!;
      if (entities.containsKey(entity)) return entities[entity]!;
      final code = entity.startsWith('#x')
          ? int.tryParse(entity.substring(2), radix: 16)
          : int.tryParse(entity.substring(1));
      if (code == null ||
          code < 0 ||
          code > 0x10ffff ||
          (code >= 0xd800 && code <= 0xdfff)) {
        return match.group(0)!;
      }
      return String.fromCharCode(code);
    },
  );
}

String quranTranslationShareText({
  required String reference,
  required String arabic,
  required String translation,
  String? footnotes,
  QuranTranslationSource? source,
  String? appName,
}) => [
  reference,
  arabic,
  quranTranslationPlainText(translation),
  if (footnotes != null && footnotes.trim().isNotEmpty)
    '${'quran_translation_notes'.tr}\n${quranTranslationPlainText(footnotes)}',
  if (source != null) ...[
    source.title,
    '${{source.publisher, 'QuranEnc'}.join(' · ')} · ${'quran_translation_version'.trParams({'version': source.version})}',
    source.sourceUrl,
  ],
  if (appName != null && appName.isNotEmpty) appName,
].join('\n\n');

class QuranTranslationText extends StatelessWidget {
  const QuranTranslationText({
    super.key,
    required this.text,
    this.languageCode,
    this.footnotes,
    this.style,
    this.fontSize,
  });
  final String text;
  final String? languageCode;
  final String? footnotes;
  final TextStyle? style;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final language =
        languageCode ?? Localizations.localeOf(context).languageCode;
    final rtl = const {
      'ar',
      'fa',
      'ur',
    }.contains(language.toLowerCase().split(RegExp('[-_]')).first);
    final direction = rtl ? TextDirection.rtl : TextDirection.ltr;
    final typography =
        (style ?? Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
            .copyWith(
              fontSize: fontSize,
              fontFamilyFallback: const ['NotoSansArabic'],
            );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          quranTranslationPlainText(text),
          key: const ValueKey('quran-translation-body'),
          textDirection: direction,
          textAlign: TextAlign.start,
          style: typography,
        ),
        if (footnotes != null && footnotes!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ExpansionTile(
              key: const ValueKey('quran-translation-notes'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: Text(
                'quran_translation_notes'.tr,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              children: [
                Align(
                  alignment: rtl ? Alignment.centerRight : Alignment.centerLeft,
                  child: SelectableText(
                    quranTranslationPlainText(footnotes!),
                    key: const ValueKey('quran-translation-footnotes'),
                    textDirection: direction,
                    textAlign: TextAlign.start,
                    style: typography,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
