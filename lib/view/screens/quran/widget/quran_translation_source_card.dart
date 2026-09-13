import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zabi/service/quran/quran_translation_repository.dart';

class QuranTranslationSourceCard extends StatefulWidget {
  const QuranTranslationSourceCard({
    super.key,
    this.source,
    this.languageCode,
    this.followsAppLanguage = false,
    this.loadSource,
    this.openSource,
  });
  final QuranTranslationSource? source;
  final String? languageCode;
  final bool followsAppLanguage;
  final Future<QuranTranslationSource> Function(String)? loadSource;
  final Future<bool> Function(Uri)? openSource;
  @override
  State<QuranTranslationSourceCard> createState() =>
      _QuranTranslationSourceCardState();
}

class _QuranTranslationSourceCardState
    extends State<QuranTranslationSourceCard> {
  Future<QuranTranslationSource>? _source;
  String? _requestedLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(QuranTranslationSourceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadSource != widget.loadSource) _requestedLanguage = null;
    _load();
  }

  void _load() {
    if (widget.source != null) return;
    final language =
        widget.languageCode ?? Localizations.localeOf(context).languageCode;
    if (_source != null && language == _requestedLanguage) return;
    _requestedLanguage = language;
    _source = Future<QuranTranslationSource>.sync(
      () => (widget.loadSource ?? QuranTranslationRepository.instance.source)(
        language,
      ),
    );
  }

  Future<void> _open(QuranTranslationSource source) async {
    try {
      final uri = Uri.tryParse(source.sourceUrl);
      if (uri == null || uri.scheme != 'https' || uri.host != 'quranenc.com') {
        throw const FormatException('Invalid source link');
      }
      final opened =
          await (widget.openSource?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened) throw StateError('Source link unavailable');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('quran_translation_link_error'.tr)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('quran-translation-source-card'),
    margin: const EdgeInsets.symmetric(vertical: 8),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: widget.source != null
          ? _details(widget.source!)
          : FutureBuilder<QuranTranslationSource>(
              future: _source,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('quran_translation_unavailable'.tr),
                      TextButton.icon(
                        key: const ValueKey('quran-translation-source-retry'),
                        onPressed: () => setState(() {
                          _source = null;
                          _load();
                        }),
                        icon: const Icon(Icons.refresh),
                        label: Text('quran_translation_retry'.tr),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return _details(snapshot.requireData);
              },
            ),
    ),
  );

  Widget _details(QuranTranslationSource source) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        (source.isTafsir ? 'tafsir_arabic' : 'quran_translation_source').tr,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      SelectableText(
        source.title,
        key: const ValueKey('quran-translation-source-title'),
        textDirection: source.isRtl ? TextDirection.rtl : TextDirection.ltr,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontFamilyFallback: const ['NotoSansArabic'],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'quran_translation_publisher'.trParams({'publisher': source.publisher}),
      ),
      Text(
        'QuranEnc · ${'quran_translation_version'.trParams({'version': source.version})}',
      ),
      if (widget.followsAppLanguage) ...[
        const SizedBox(height: 12),
        Text('quran_translation_follows_language'.tr),
      ],
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: const ValueKey('quran-translation-open-source'),
          onPressed: () => _open(source),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text('quran_translation_open_source'.tr),
        ),
      ),
    ],
  );
}
