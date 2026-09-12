import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Sensor-independent presentation. North is at the top of the painted dial.
class QiblaDialView extends StatelessWidget {
  const QiblaDialView({
    super.key,
    required this.heading,
    required this.bearing,
    required this.deviceAngle,
    required this.needleAngle,
  });
  final double heading, bearing, deviceAngle, needleAngle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final foreground = theme.colorScheme.onSurface;
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final diameter = math.min(390.0, constraints.maxWidth - 48);
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.navigation_rounded, color: primary, size: 36),
                    const SizedBox(height: 12),
                    Semantics(
                      label:
                          '${'qibla_compass'.tr} ${bearing.round()}°, ${'current_heading'.tr} ${heading.round()}°',
                      child: SizedBox.square(
                        dimension: diameter,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _rotation(
                              -deviceAngle,
                              CustomPaint(
                                painter: _DialPainter(
                                  surface: theme.cardColor,
                                  primary: primary,
                                  ink: foreground,
                                ),
                              ),
                            ),
                            _rotation(
                              needleAngle,
                              const CustomPaint(painter: _NeedlePainter()),
                            ),
                            Container(
                              width: diameter * .095,
                              height: diameter * .095,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    theme.cardColor,
                                    Color.alphaBlend(
                                      primary.withValues(alpha: .2),
                                      theme.cardColor,
                                    ),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xff90682a),
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 28,
                      runSpacing: 20,
                      children: [
                        _reading(context, 'qibla_compass'.tr, bearing),
                        _reading(context, 'current_heading'.tr, heading),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${((bearing - heading + 540) % 360 - 180).abs().round()}° · ${'device_angle_to_qibla'.tr}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foreground.withValues(alpha: .7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _reading(BuildContext context, String label, double value) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${value.round() % 360}°',
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontSize: 30,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .7),
          fontSize: 14,
        ),
      ),
    ],
  );

  Widget _rotation(double degrees, Widget child) => Positioned.fill(
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: degrees),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      builder: (_, angle, child) =>
          Transform.rotate(angle: angle * math.pi / 180, child: child),
      child: RepaintBoundary(child: child),
    ),
  );
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.surface,
    required this.primary,
    required this.ink,
  });
  final Color surface, primary, ink;
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.translate(r, r);
    final bounds = Rect.fromCircle(center: Offset.zero, radius: r - 3);
    canvas.drawShadow(Path()..addOval(bounds), Colors.black, 10, true);
    canvas.drawCircle(
      Offset.zero,
      r - 3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            surface,
            Color.alphaBlend(primary.withValues(alpha: .09), surface),
          ],
        ).createShader(bounds),
    );
    canvas.drawCircle(
      Offset.zero,
      r - 3,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset.zero,
      r * .87,
      Paint()
        ..color = primary.withValues(alpha: .4)
        ..style = PaintingStyle.stroke,
    );
    for (int i = 0; i < 120; i++) {
      final angle = i * math.pi / 60;
      final major = i % 10 == 0;
      final outer = r * .855;
      final inner =
          r *
          (major
              ? .755
              : i % 5 == 0
              ? .785
              : .815);
      final paint = Paint()
        ..color = ink.withValues(alpha: .8)
        ..strokeWidth = major ? 1.8 : 1;
      canvas.drawLine(
        Offset(math.sin(angle) * inner, -math.cos(angle) * inner),
        Offset(math.sin(angle) * outer, -math.cos(angle) * outer),
        paint,
      );
      if (major) {
        _text(
          canvas,
          '${i * 3}',
          Offset(math.sin(angle) * r * .925, -math.cos(angle) * r * .925),
          r * .052,
          ink.withValues(alpha: .8),
        );
      }
    }
    for (int i = 0; i < 8; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 4);
      final length = r * (i.isEven ? .53 : .36);
      canvas.drawPath(
        Path()
          ..moveTo(0, -length)
          ..lineTo(r * .09, 0)
          ..lineTo(0, r * .09)
          ..close(),
        Paint()..color = primary.withValues(alpha: .3),
      );
      canvas.drawPath(
        Path()
          ..moveTo(0, -length)
          ..lineTo(-r * .09, 0)
          ..lineTo(0, r * .09)
          ..close(),
        Paint()..color = primary.withValues(alpha: .14),
      );
      canvas.restore();
    }
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      _text(
        canvas,
        ['N', 'E', 'S', 'W'][i],
        Offset(math.sin(a) * r * .66, -math.cos(a) * r * .66),
        r * .10,
        i == 0 ? const Color(0xffb64c3e) : ink.withValues(alpha: .8),
      );
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset center,
    double size,
    Color color,
  ) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: size,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      surface != oldDelegate.surface ||
      primary != oldDelegate.primary ||
      ink != oldDelegate.ink;
}

class _NeedlePainter extends CustomPainter {
  const _NeedlePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.translate(r, r);
    final path = Path()
      ..moveTo(0, -r * .62)
      ..lineTo(r * .17, -r * .025)
      ..cubicTo(r * .28, r * .32, -r * .28, r * .32, -r * .17, -r * .025)
      ..close();
    canvas.drawShadow(path, Colors.black54, 5, true);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffffdd73), Color(0xffdca326), Color(0xffa96d10)],
        ).createShader(Rect.fromLTWH(-r * .2, -r * .62, r * .4, r * .85)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xff9a731f)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final kaaba = Rect.fromCenter(
      center: Offset(0, -r * .29),
      width: r * .13,
      height: r * .15,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(kaaba, const Radius.circular(2)),
      Paint()..color = const Color(0xff414135),
    );
    canvas.drawRect(
      Rect.fromLTWH(kaaba.left, kaaba.top + r * .025, kaaba.width, r * .025),
      Paint()..color = const Color(0xffffd773),
    );
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) => false;
}
