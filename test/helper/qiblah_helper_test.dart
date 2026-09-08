import 'package:flutter_test/flutter_test.dart';
import 'package:zabi/helper/qiblah_helper.dart';

void main() {
  group('QiblahHelper.bearingFromTrueNorth', () {
    test('points east-southeast from Fes', () {
      final bearing = QiblahHelper.bearingFromTrueNorth(34.0181, -5.0078);

      expect(bearing, closeTo(95.79, 0.02));
    });

    test('points northeast from New York', () {
      final bearing = QiblahHelper.bearingFromTrueNorth(40.7128, -74.0060);

      expect(bearing, closeTo(58.48, 0.02));
    });

    test('points northwest from Jakarta', () {
      final bearing = QiblahHelper.bearingFromTrueNorth(-6.2088, 106.8456);

      expect(bearing, closeTo(295.15, 0.02));
    });
  });

  group('QiblahHelper compass angles', () {
    test('returns zero when the phone points at the Qiblah', () {
      expect(
        QiblahHelper.clockwiseAngleToQiblah(
          trueHeading: 95.79,
          qiblahBearing: 95.79,
        ),
        closeTo(0, 0.001),
      );
    });

    test('uses the shortest displayed distance across north', () {
      expect(
        QiblahHelper.angularDistanceToQiblah(
          trueHeading: 5,
          qiblahBearing: 355,
        ),
        closeTo(10, 0.001),
      );
    });

    test('rotates clockwise from north towards the Fes bearing', () {
      expect(
        QiblahHelper.clockwiseAngleToQiblah(
          trueHeading: 0,
          qiblahBearing: 95.79,
        ),
        closeTo(95.79, 0.001),
      );
    });

    test('compensates the bundled compass artwork north offset', () {
      expect(QiblahHelper.compassDialHeading(0), closeTo(22.5, 0.001));
      expect(QiblahHelper.compassDialHeading(90), closeTo(112.5, 0.001));
      expect(QiblahHelper.compassDialHeading(350), closeTo(12.5, 0.001));
    });
  });
}
