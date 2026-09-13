import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salatime/theme/brand_colors.dart';
import 'package:salatime/util/images.dart';

/// Sample content using the dimensions, illustration and palette of the
/// Android widget layouts. It scales like an image, independently of UI text.
class PrayerWidgetPreview extends StatelessWidget {
  const PrayerWidgetPreview({super.key, required this.size});

  final String size;

  @override
  Widget build(BuildContext context) {
    final large = size == 'large';
    final width = size == 'small' ? 160.0 : (large ? 300.0 : 250.0);
    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: MediaQuery.withClampedTextScaling(
          minScaleFactor: 1,
          maxScaleFactor: 1,
          child: Container(
            width: width,
            height: large ? 180 : 80,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: .8)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFAF5E9), Color(0xFFF1F4EB)],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: .42,
                  child: Image.asset(
                    Images.ModernIllustration_MosqueHeader,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: large ? 16 : 7,
                  ),
                  child: Column(
                    children: [
                      if (large)
                        const Row(
                          children: [
                            Icon(
                              Icons.nights_stay_outlined,
                              size: 16,
                              color: BrandColors.primary,
                            ),
                            SizedBox(width: 6),
                            _PreviewText('SalaTime', size: 12),
                          ],
                        ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _PreviewText('next_prayer'.tr, size: 10),
                                  const SizedBox(height: 3),
                                  _PreviewText(
                                    'fajr'.tr,
                                    size: large ? 25 : 23,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: _PreviewText(
                                    '05:36',
                                    size: large ? 42 : 36,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (large) ...[
                        const Divider(height: 12, color: Color(0x1A2F5233)),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              for (final entry in const [
                                ('widget_prayer_1', '05:36'),
                                ('widget_prayer_2', '13:16'),
                                ('widget_prayer_3', '16:48'),
                                ('widget_prayer_4', '19:31'),
                                ('widget_prayer_5', '20:55'),
                              ])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Column(
                                      children: [
                                        _PreviewText(entry.$1.tr, size: 10),
                                        const SizedBox(height: 3),
                                        _PreviewText(entry.$2, size: 12),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewText extends StatelessWidget {
  const _PreviewText(this.text, {required this.size});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      maxLines: 1,
      style: TextStyle(
        color: BrandColors.primary,
        fontSize: size,
        fontWeight: size < 20 ? FontWeight.w500 : FontWeight.w600,
      ),
    ),
  );
}
