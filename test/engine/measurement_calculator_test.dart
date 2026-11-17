import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/calculation_result.dart';
import 'package:ustametre/engine/calculator.dart';
import 'package:ustametre/engine/calculators/measurement_calculator.dart';
import 'package:ustametre/engine/measurement.dart';
import 'package:ustametre/engine/money.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);
  Money tl(String s) => Money.fromDecimal(d(s));
  const calc = MeasurementCalculator();

  ResultFigure main(CalculationResult r) =>
      r.figures.firstWhere((f) => f.highlighted);

  group('Hesap türleri', () {
    test('uzunluk: 1250 mm × 3 adet = 3,75 m', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.length,
          unit: LengthUnit.millimeter,
          length: d('1250'),
          quantity: 3,
        ),
      );
      expect(main(r).value, d('3.75'));
      expect(main(r).unit, 'm');
      expect(r.price, isNull);
    });

    test('alan: 1234 mm × 567 mm = 0,699678 m²', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.area,
          unit: LengthUnit.millimeter,
          length: d('1234'),
          width: d('567'),
          unitPrice: tl('99.99'),
        ),
      );
      expect(main(r).value, d('0.699678'));
      // 0,699678 × 99,99 = 69,96080322 → 69,96
      expect(r.price!.subtotal, tl('69.96'));
    });

    test('hacim: 200 × 30 × 15 cm × 2 adet = 0,18 m³', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.volume,
          unit: LengthUnit.centimeter,
          length: d('200'),
          width: d('30'),
          height: d('15'),
          quantity: 2,
        ),
      );
      expect(main(r).value, d('0.18'));
      expect(main(r).unit, 'm³');
    });

    test('hacim fiyatı ve KDV: 2 × 0,3 × 0,15 m × 2 = 0,18 m³', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.volume,
          length: d('2'),
          width: d('0.3'),
          height: d('0.15'),
          quantity: 2,
          unitPrice: tl('2450'),
          vatPercent: d('20'),
        ),
      );
      expect(main(r).value, d('0.18'));
      expect(r.price!.subtotal, tl('441'));
      expect(r.price!.vat, tl('88.2'));
      expect(r.price!.grandTotal, tl('529.2'));
    });

    test('metre tül: 3,5 m × ₺1.250,75 = ₺4.377,63 (yarım yukarı)', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.linearMeter,
          length: d('3.5'),
          unitPrice: tl('1250.75'),
        ),
      );
      expect(main(r).value, d('3.5'));
      expect(main(r).unit, 'mtül');
      expect(r.price!.subtotal, tl('4377.63'));
    });

    test('çevre: 2 × (120 + 80 cm) × 2 adet = 8 m', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.perimeter,
          unit: LengthUnit.centimeter,
          length: d('120'),
          width: d('80'),
          quantity: 2,
        ),
      );
      expect(main(r).value, d('8'));
    });

    test('adet × birim fiyat', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.piece,
          quantity: 12,
          unitPrice: tl('37.5'),
        ),
      );
      expect(main(r).value, d('12'));
      expect(r.price!.subtotal, tl('450'));
    });

    test('manuel: 7,25 birim × 2 adet × ₺10', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.manual,
          manualAmount: d('7.25'),
          quantity: 2,
          unitPrice: tl('10'),
        ),
      );
      expect(main(r).value, d('14.5'));
      expect(r.price!.subtotal, tl('145'));
    });
  });

  group('Fire', () {
    test('alan %10 fire: 6 m² → 6,6 m²', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.area,
          length: d('2'),
          width: d('3'),
          wastePercent: d('10'),
        ),
      );
      expect(r.figures[0].value, d('6'));
      expect(r.figures[1].value, d('0.6')); // fire miktarı
      expect(main(r).value, d('6.6'));
    });

    test('ondalıklı fire oranı: %7,5', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.length,
          length: d('4'),
          wastePercent: d('7.5'),
        ),
      );
      expect(main(r).value, d('4.3'));
    });

    test('fire fiyata yansır', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.area,
          length: d('2'),
          width: d('3'),
          wastePercent: d('10'),
          unitPrice: tl('99.99'),
        ),
      );
      // 6,6 × 99,99 = 659,934 → 659,93
      expect(r.price!.subtotal, tl('659.93'));
    });

    test('adet fireli miktar yukarı tam sayıya yuvarlanır', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.piece,
          quantity: 10,
          wastePercent: d('5'),
          unitPrice: tl('12.5'),
        ),
      );
      expect(main(r).value, d('11')); // 10,5 → 11
      expect(r.price!.subtotal, tl('137.5'));
    });

    test('fire %0 iken fire satırı gösterilmez', () {
      final r = calc.calculate(
        MeasurementInput(type: MeasurementType.length, length: d('2')),
      );
      expect(r.figures, hasLength(1));
    });
  });

  group('Doğrulama', () {
    void rejects(MeasurementInput input, String message) {
      expect(
        () => calc.calculate(input),
        throwsA(
          isA<CalculationException>().having(
            (e) => e.message,
            'message',
            message,
          ),
        ),
      );
    }

    test('eksik ölçüler', () {
      rejects(
        const MeasurementInput(type: MeasurementType.area),
        'Uzunluk girin.',
      );
      rejects(
        MeasurementInput(type: MeasurementType.area, length: d('1')),
        'Genişlik girin.',
      );
      rejects(
        MeasurementInput(
          type: MeasurementType.volume,
          length: d('1'),
          width: d('1'),
        ),
        'Yükseklik girin.',
      );
      rejects(
        const MeasurementInput(type: MeasurementType.manual),
        'Miktar girin.',
      );
    });

    test('sıfır ve aralık dışı değerler', () {
      rejects(
        MeasurementInput(type: MeasurementType.length, length: d('0')),
        'Uzunluk sıfırdan büyük olmalıdır.',
      );
      rejects(
        MeasurementInput(
          type: MeasurementType.length,
          length: d('1'),
          wastePercent: d('150'),
        ),
        'Fire oranı %0 ile %100 arasında olmalıdır.',
      );
      rejects(
        MeasurementInput(
          type: MeasurementType.length,
          length: d('1'),
          vatPercent: d('-1'),
        ),
        'KDV oranı %0 ile %100 arasında olmalıdır.',
      );
      rejects(
        const MeasurementInput(type: MeasurementType.piece, quantity: 0),
        'Adet en az 1 olmalıdır.',
      );
    });
  });

  group('Nasıl hesaplandı', () {
    test('adımlar dönüşüm, alan, fire, fiyat ve KDV içerir', () {
      final r = calc.calculate(
        MeasurementInput(
          type: MeasurementType.area,
          unit: LengthUnit.centimeter,
          length: d('120'),
          width: d('60'),
          quantity: 2,
          wastePercent: d('10'),
          unitPrice: tl('450'),
          vatPercent: d('20'),
        ),
      );
      expect(r.steps, [
        'Ölçüler metreye çevrildi: Uzunluk 120 cm = 1,2 m; '
            'Genişlik 60 cm = 0,6 m',
        'Alan = 1,2 m × 0,6 m × 2 adet = 1,44 m²',
        'Fire %10: 1,44 m² × 1,1 = 1,584 m²',
        'Alan tutarı = 1,584 m² × ₺450,00/m² = ₺712,80',
        'Ara toplam = ₺712,80',
        'KDV %20 = ₺712,80 × %20 = ₺142,56',
        'Genel toplam = ₺712,80 + ₺142,56 = ₺855,36',
      ]);
      expect(r.price!.grandTotal, tl('855.36'));
    });

    test('metre biriminde dönüşüm adımı yoktur', () {
      final r = calc.calculate(
        MeasurementInput(type: MeasurementType.length, length: d('2')),
      );
      expect(r.steps.first, startsWith('Uzunluk ='));
    });
  });
}
