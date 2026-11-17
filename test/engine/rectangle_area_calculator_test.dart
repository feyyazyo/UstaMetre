import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/calculator.dart';
import 'package:ustametre/engine/calculators/rectangle_area_calculator.dart';
import 'package:ustametre/engine/measurement.dart';
import 'package:ustametre/engine/money.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);
  const calc = RectangleAreaCalculator();

  group('Length', () {
    test('birim dönüşümleri kesindir', () {
      final l = Length(d('1234.5'), LengthUnit.millimeter);
      expect(l.meters, d('1.2345'));
      expect(l.inUnit(LengthUnit.centimeter), d('123.45'));
      expect(
        Length(d('0.1'), LengthUnit.meter) + Length(d('0.2'), LengthUnit.meter),
        Length(d('0.3'), LengthUnit.meter),
      );
    });
  });

  group('RectangleAreaCalculator', () {
    test('cm girişiyle alan ve fiyat', () {
      final r = calc.calculate(
        RectangleAreaInput(
          width: Length(d('60'), LengthUnit.centimeter),
          height: Length(d('120'), LengthUnit.centimeter),
          quantity: 3,
          unitPricePerSquareMeter: Money.fromDecimal(d('450')),
        ),
      );
      expect(r.netArea.squareMeters, d('2.16'));
      expect(r.totalArea.squareMeters, d('2.16'));
      expect(r.totalPrice, Money.fromDecimal(d('972')));
    });

    test('fire oranı toplam alana eklenir', () {
      final r = calc.calculate(
        RectangleAreaInput(
          width: Length(d('2'), LengthUnit.meter),
          height: Length(d('3'), LengthUnit.meter),
          wastePercent: d('10'),
          unitPricePerSquareMeter: Money.fromDecimal(d('99.99')),
        ),
      );
      expect(r.netArea.squareMeters, d('6'));
      expect(r.totalArea.squareMeters, d('6.6'));
      expect(r.totalPrice, Money.fromDecimal(d('659.93'))); // 659.934
    });

    test('birim fiyat yoksa fiyat hesaplanmaz', () {
      final r = calc.calculate(
        RectangleAreaInput(
          width: Length(d('0.1'), LengthUnit.meter),
          height: Length(d('0.3'), LengthUnit.meter),
        ),
      );
      expect(r.netArea.squareMeters, d('0.03'));
      expect(r.totalPrice, isNull);
    });

    test('geçersiz girdiler reddedilir', () {
      RectangleAreaInput input({
        String w = '1',
        String h = '1',
        int q = 1,
        String waste = '0',
        String? price,
      }) => RectangleAreaInput(
        width: Length(d(w), LengthUnit.meter),
        height: Length(d(h), LengthUnit.meter),
        quantity: q,
        wastePercent: d(waste),
        unitPricePerSquareMeter: price == null
            ? null
            : Money.fromDecimal(d(price)),
      );

      final invalid = [
        input(w: '0'),
        input(h: '-1'),
        input(q: 0),
        input(waste: '-5'),
        input(price: '-1'),
      ];
      for (final i in invalid) {
        expect(() => calc.calculate(i), throwsA(isA<CalculationException>()));
      }
    });
  });
}
