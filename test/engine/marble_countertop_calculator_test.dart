import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/calculation_result.dart';
import 'package:ustametre/engine/calculator.dart';
import 'package:ustametre/engine/calculators/marble_countertop_calculator.dart';
import 'package:ustametre/engine/measurement.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/engine/pricing.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);
  Money tl(String s) => Money.fromDecimal(d(s));
  const calc = MarbleCountertopCalculator();

  Decimal figure(CalculationResult result, String label) =>
      result.figures.firstWhere((f) => f.label.startsWith(label)).value;

  group('Mermer tezgâh', () {
    test('dikdörtgen tezgâh m²: 250 × 62 cm = 1,55 m²', () {
      final r = calc.calculate(
        MarbleCountertopInput(length: d('250'), depth: d('62')),
      );
      expect(figure(r, 'Net alan'), d('1.55'));
      expect(figure(r, 'Metre tül'), d('2.5'));
      expect(r.price, isNull);
    });

    test('fireli m²: %10 fire → 1,705 m²', () {
      final r = calc.calculate(
        MarbleCountertopInput(
          length: d('250'),
          depth: d('62'),
          wastePercent: d('10'),
        ),
      );
      expect(figure(r, 'Fireli alan'), d('1.705'));
    });

    test('metre tül adetle çarpılır, fire uygulanmaz', () {
      final r = calc.calculate(
        MarbleCountertopInput(
          unit: LengthUnit.millimeter,
          length: d('1800'),
          depth: d('600'),
          quantity: 2,
          wastePercent: d('15'),
        ),
      );
      expect(figure(r, 'Metre tül'), d('3.6'));
      expect(figure(r, 'Net alan'), d('2.16'));
    });

    test('işçilik ve malzeme toplamı, KDV ve genel toplam', () {
      final r = calc.calculate(
        MarbleCountertopInput(
          length: d('250'),
          depth: d('62'),
          wastePercent: d('10'),
          materialPricePerSquareMeter: tl('3200'),
          laborPricePerLinearMeter: tl('450'),
          vatPercent: d('20'),
        ),
      );
      final p = r.price!;
      expect(p.totalOf(CostKind.material), tl('5456')); // 1,705 × 3200
      expect(p.totalOf(CostKind.labor), tl('1125')); // 2,5 × 450
      expect(p.subtotal, tl('6581'));
      expect(p.vat, tl('1316.2'));
      expect(p.grandTotal, tl('7897.2'));
      expect(r.steps.last, 'Genel toplam = ₺6.581,00 + ₺1.316,20 = ₺7.897,20');
    });

    test('yalnızca işçilik fiyatı girilirse yalnızca işçilik hesaplanır', () {
      final r = calc.calculate(
        MarbleCountertopInput(
          length: d('300'),
          depth: d('60'),
          laborPricePerLinearMeter: tl('400'),
        ),
      );
      expect(r.price!.lines, hasLength(1));
      expect(r.price!.lines.single.kind, CostKind.labor);
      expect(r.price!.grandTotal, tl('1200'));
    });

    test('eksik derinlik reddedilir', () {
      expect(
        () => calc.calculate(MarbleCountertopInput(length: d('250'))),
        throwsA(
          isA<CalculationException>().having(
            (e) => e.message,
            'message',
            'Derinlik girin.',
          ),
        ),
      );
    });
  });
}
