import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/measurement.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/features/calculations/calculation_form.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);
  Money tl(String s) => Money.fromDecimal(d(s));

  group('evaluateForm', () {
    test('Türkçe sayı girişleriyle tezgâh hesabı', () {
      final e = evaluateForm(
        mode: CalcMode.marbleCountertop,
        unit: LengthUnit.centimeter,
        values: {
          CalcField.length: '250',
          CalcField.width: '62',
          CalcField.quantity: '1',
          CalcField.waste: '10',
          CalcField.materialPrice: '3.200',
          CalcField.laborPrice: '450,00',
          CalcField.vat: '20',
        },
      );
      expect(e.fieldErrors, isEmpty);
      expect(e.result!.price!.grandTotal, tl('7897.2'));
    });

    test('binlik ayırıcılı mm ölçüsü: "1.250" mm = 1,25 m', () {
      final e = evaluateForm(
        mode: CalcMode.length,
        unit: LengthUnit.millimeter,
        values: {CalcField.length: '1.250', CalcField.unitPrice: '1.250,75'},
      );
      final r = e.result!;
      expect(r.figures.single.value, d('1.25'));
      // 1,25 × 1.250,75 = 1.563,4375 → 1.563,44
      expect(r.price!.subtotal, tl('1563.44'));
    });

    test('boş adet 1 kabul edilir, boş KDV %0', () {
      final e = evaluateForm(
        mode: CalcMode.piece,
        unit: LengthUnit.meter,
        values: {CalcField.unitPrice: '15'},
      );
      expect(e.result!.figures.single.value, d('1'));
      expect(e.result!.price!.grandTotal, tl('15'));
    });

    test('geçersiz sayı alan hatası verir', () {
      final e = evaluateForm(
        mode: CalcMode.area,
        unit: LengthUnit.centimeter,
        values: {CalcField.length: '1,2,3', CalcField.width: '50'},
      );
      expect(e.result, isNull);
      expect(e.fieldErrors[CalcField.length], invalidNumberMessage);
    });

    test('ondalıklı adet reddedilir', () {
      final e = evaluateForm(
        mode: CalcMode.piece,
        unit: LengthUnit.meter,
        values: {CalcField.quantity: '2,5'},
      );
      expect(e.fieldErrors, contains(CalcField.quantity));
    });

    test('eksik ölçüde motorun açıklaması gösterilir', () {
      final e = evaluateForm(
        mode: CalcMode.volume,
        unit: LengthUnit.centimeter,
        values: {CalcField.length: '100', CalcField.width: '50'},
      );
      expect(e.result, isNull);
      expect(e.message, 'Yükseklik girin.');
    });

    test('mod yalnızca kendi alanlarını kullanır', () {
      expect(CalcMode.piece.fields, isNot(contains(CalcField.length)));
      expect(CalcMode.volume.fields, contains(CalcField.height));
      expect(CalcMode.marbleCountertop.fieldLabel(CalcField.width), 'Derinlik');
      expect(
        CalcMode.area.fieldLabel(CalcField.unitPrice),
        'Birim fiyat (₺/m²)',
      );
    });

    test('mermerde tezgâh ilk, diğer kategorilerde yok', () {
      expect(
        modesForCategory('marble_granite').first,
        CalcMode.marbleCountertop,
      );
      expect(
        modesForCategory('ceramic_tile'),
        isNot(contains(CalcMode.marbleCountertop)),
      );
      expect(modesForCategory('ceramic_tile'), hasLength(7));
    });
  });
}
