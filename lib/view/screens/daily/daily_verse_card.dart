import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zabi/helper/daily_verse.dart';

class DailyVerseCard extends StatefulWidget {
  const DailyVerseCard({super.key});
  @override
  State<DailyVerseCard> createState() => _DailyVerseCardState();
}

class _DailyVerseCardState extends State<DailyVerseCard>
    with WidgetsBindingObserver {
  Timer? _midnight;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armMidnight();
  }

  void _armMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    _midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        if (mounted) {
          setState(() {
            _day = DateTime.now();
            verse = _load();
          });
        }
        _armMidnight();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {
          _day = DateTime.now();
          verse = _load();
        });
      }
      _armMidnight();
    } else if (state == AppLifecycleState.paused) {
      _midnight?.cancel();
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime _day = DateTime.now();
  late Future<DailyVerse> verse = _load();
  @override
  void didUpdateWidget(covariant DailyVerseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final now = DateTime.now();
    if (DailyVerse.dayIndex(now) != DailyVerse.dayIndex(_day)) {
      _day = now;
      verse = _load();
    }
  }

  Future<DailyVerse> _load() async {
    final prefs = await SharedPreferences.getInstance();
    return DailyVerse.load(
      DateTime.now(),
      prefs.getString('selectedTranslatorId') ??
          (Get.locale?.languageCode == 'ar' ? '4' : '1'),
    );
  }

  void _open(DailyVerse verse) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '${'verse_of_day'.tr} · ${verse.chapter}:${verse.number}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          SelectableText(
            verse.arabic,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 26, height: 1.7),
          ),
          const SizedBox(height: 16),
          SelectableText(
            verse.translation,
            textDirection: verse.source == 'تفسير الجلالين'
                ? TextDirection.rtl
                : null,
          ),
          Text(verse.source, style: Theme.of(context).textTheme.bodySmall),
          const Divider(height: 32),
          Text(
            'tafsir_arabic'.tr,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SelectableText(
            verse.tafsir.isEmpty ? 'tafsir_unavailable'.tr : verse.tafsir,
            textDirection: TextDirection.rtl,
            style: const TextStyle(height: 1.7),
          ),
          const Text('تفسير الجلالين', textDirection: TextDirection.rtl),
          const SizedBox(height: 20),
          Builder(
            builder: (context) => OutlinedButton.icon(
              onPressed: () async {
                final box = context.findRenderObject() as RenderBox?;
                try {
                  await SharePlus.instance.share(
                    ShareParams(
                      text:
                          '${verse.arabic}\n\n${verse.translation}\n${verse.source}\n${verse.chapter}:${verse.number} — SalaTime',
                      sharePositionOrigin: box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size,
                    ),
                  );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('please_try_again'.tr)),
                    );
                  }
                }
              },
              icon: const Icon(Icons.share_outlined),
              label: Text('share'.tr),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<DailyVerse>(
    future: verse,
    builder: (context, snapshot) {
      final value = snapshot.data;
      if (value == null) return const SizedBox.shrink();
      return Card(
        child: InkWell(
          onTap: () => _open(value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'verse_of_day'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  value.arabic,
                  textDirection: TextDirection.rtl,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 23, height: 1.5),
                ),
                const SizedBox(height: 12),
                Text(
                  '${value.chapter}:${value.number} · ${'read_tafsir'.tr}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
