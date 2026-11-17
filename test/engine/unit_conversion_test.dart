import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/measurement.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);

  group('Birim dönüşümleri', () {
    test('mm → m', () {
      expect(Length(d('1'), LengthUnit.millimeter).meters, d('0.001'));
      expect(Length(d('1250'), LengthUnit.millimeter).meters, d('1.25'));
      expect(Length(d('0.5'), LengthUnit.millimeter).meters, d('0.0005'));
    });

    test('cm → m', () {
      expect(Length(d('1'), LengthUnit.centimeter).meters, d('0.01'));
      expect(Length(d('62'), LengthUnit.centimeter).meters, d('0.62'));
      expect(Length(d('250.5'), LengthUnit.centimeter).meters, d('2.505'));
    });

    test('m → m', () {
      expect(Length(d('3.75'), LengthUnit.meter).meters, d('3.75'));
    });

    test('m → mm / cm geri dönüşüm kayıpsız', () {
      final l = Length(d('1.2345'), LengthUnit.meter);
      expect(l.inUnit(LengthUnit.millimeter), d('1234.5'));
      expect(l.inUnit(LengthUnit.centimeter), d('123.45'));
      expect(l.inUnit(LengthUnit.meter), d('1.2345'));
    });

    test('farklı birimlerde aynı uzunluk eşittir', () {
      expect(
        Length(d('1500'), LengthUnit.millimeter),
        Length(d('150'), LengthUnit.centimeter),
      );
      expect(
        Length(d('150'), LengthUnit.centimeter),
        Length(d('1.5'), LengthUnit.meter),
      );
    });
  });

  group('Alan ve hacim', () {
    test('cm × cm → m²', () {
      final area =
          Length(d('250'), LengthUnit.centimeter) *
          Length(d('62'), LengthUnit.centimeter);
      expect(area.squareMeters, d('1.55'));
    });

    test('mm × mm → m² kesin (kayan nokta yok)', () {
      final area =
          Length(d('1234'), LengthUnit.millimeter) *
          Length(d('567'), LengthUnit.millimeter);
      expect(area.squareMeters, d('0.699678'));
    });

    test('alan × yükseklik → m³', () {
      final volume =
          Length(d('200'), LengthUnit.centimeter) *
          Length(d('30'), LengthUnit.centimeter) *
          Length(d('15'), LengthUnit.centimeter);
      expect(volume.cubicMeters, d('0.09'));
    });

    test('0,1 m × 0,1 m tam olarak 0,01 m²', () {
      final area =
          Length(d('0.1'), LengthUnit.meter) *
          Length(d('0.1'), LengthUnit.meter);
      expect(area.squareMeters, d('0.01'));
    });
  });
}
