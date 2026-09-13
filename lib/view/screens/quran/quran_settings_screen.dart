import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zabi/controller/quran_settings_controller.dart';
import 'package:zabi/view/screens/quran/widget/quran_translation_source_card.dart';

void openBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    enableDrag: false,
    isDismissible: false,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const QuranReaderSettingsSheet(),
  );
}

class QuranReaderSettingsSheet extends StatelessWidget {
  const QuranReaderSettingsSheet({
    super.key,
    this.sourceCard = const QuranTranslationSourceCard(
      followsAppLanguage: true,
    ),
  });
  final Widget sourceCard;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: GetBuilder<SettingsController>(
        builder: (settings) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'quran_settings'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'close'.tr,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Obx(
                () => _fontSlider(
                  context,
                  'arabic_font_size',
                  settings.arabicFontSize.value,
                  14,
                  40,
                  settings.changeArabicFontSize,
                ),
              ),
              const Divider(),
              Obx(
                () => _fontSlider(
                  context,
                  'translate_font_size',
                  settings.translateFontSize.value,
                  12,
                  24,
                  settings.changeTranslateFontSize,
                ),
              ),
              const Divider(),
              Text(
                'arabic_font_style'.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Obx(
                () => settings.isSelectedFontLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        key: const ValueKey('quran-arabic-font'),
                        initialValue:
                            settings.availableFonts.contains(
                              settings.selectedFont.value,
                            )
                            ? settings.selectedFont.value
                            : settings.availableFonts.first,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final font in settings.availableFonts)
                            DropdownMenuItem(
                              value: font,
                              child: Text(
                                font,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (font) {
                          if (font != null) settings.changeArabicFont(font);
                        },
                      ),
              ),
              const SizedBox(height: 12),
              sourceCard,
            ],
          ),
        ),
      ),
    ),
  );

  Widget _fontSlider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label.tr, style: Theme.of(context).textTheme.titleMedium),
      Row(
        children: [
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          Text(value.toStringAsFixed(0)),
        ],
      ),
    ],
  );
}
