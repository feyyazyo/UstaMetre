import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/calculator.dart';
import 'package:ustametre/engine/calculators/measurement_calculator.dart';
import 'package:ustametre/engine/costing/cost_item.dart';
import 'package:ustametre/engine/costing/cost_sheet.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/engine/pricing.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);
  Money tl(String s) => Money.fromDecimal(d(s));

  CostItem item(
    String id, {
    String name = 'Kalem',
    CostKind category = CostKind.material,
    String qty = '1',
    CostUnit unit = CostUnit.piece,
    String price = '100',
  }) => CostItem(
    id: id,
    name: name,
    category: category,
    quantity: d(qty),
    unit: unit,
    unitPrice: tl(price),
  );

  group('CostItem', () {
    test('toplam = miktar × birim fiyat, kuruşa yuvarlanır', () {
      expect(item('a', qty: '2', price: '37.5').total, tl('75'));
      expect(item('a', qty: '1.333', price: '10').total, tl('13.33'));
      expect(item('a', qty: '0.125', price: '0.1').total, tl('0.01'));
    });

    test('doğrulama: boş ad, sıfır miktar, negatif fiyat', () {
      expect(
        () => item('a', name: '  ').validate(),
        throwsA(isA<CalculationException>()),
      );
      expect(
        () => item('a', qty: '0').validate(),
        throwsA(isA<CalculationException>()),
      );
      expect(
        () => item('a', price: '-1').validate(),
        throwsA(isA<CalculationException>()),
      );
      item('a').validate(); // geçerli kalem hata vermez
    });

    test('JSON gidiş-dönüş kayıpsız', () {
      final original =
          item(
            'x',
            name: 'Evye montajı',
            category: CostKind.labor,
            qty: '1.5',
            unit: CostUnit.hour,
            price: '1250.75',
          ).copyWith(
            description: 'Alttan montaj',
            source: PriceSource(
              priceListItemId: 'pl1',
              effectiveFrom: DateTime.utc(2026, 11, 1),
            ),
          );
      final back = CostItem.fromJson(original.toJson());
      expect(back.toJson(), original.toJson());
      expect(back.total, original.total);
    });
  });

  group('CostSheet işlemleri', () {
    test('ekleme', () {
      final sheet = const CostSheet().add(item('a')).add(item('b'));
      expect(sheet.items.map((i) => i.id), ['a', 'b']);
      expect(() => sheet.add(item('a')), throwsArgumentError);
    });

    test('düzenleme sırayı korur', () {
      final sheet = const CostSheet()
          .add(item('a'))
          .add(item('b'))
          .add(item('c'));
      final edited = sheet.update(item('b', name: 'Yeni ad', price: '250'));
      expect(edited.items.map((i) => i.id), ['a', 'b', 'c']);
      expect(edited.byId('b')!.name, 'Yeni ad');
      expect(edited.byId('b')!.total, tl('250'));
      // Orijinal liste değişmez.
      expect(sheet.byId('b')!.total, tl('100'));
      expect(() => sheet.update(item('zzz')), throwsStateError);
    });

    test('silme', () {
      final sheet = const CostSheet().add(item('a')).add(item('b'));
      expect(sheet.remove('a').items.map((i) => i.id), ['b']);
      expect(sheet.remove('yok').items, hasLength(2));
    });

    test('kopyalama: yeni kimlik, "(kopya)" adı, hemen arkasında', () {
      final sheet = const CostSheet()
          .add(item('a', name: 'Sakal'))
          .add(item('b'));
      final copied = sheet.duplicate('a', newId: 'a2');
      expect(copied.items.map((i) => i.id), ['a', 'a2', 'b']);
      expect(copied.byId('a2')!.name, 'Sakal (kopya)');
      expect(copied.byId('a2')!.total, copied.byId('a')!.total);
    });

    test('toplamlar ve kategori toplamları', () {
      final sheet = const CostSheet()
          .add(item('a', category: CostKind.material, qty: '2', price: '100'))
          .add(item('b', category: CostKind.labor, price: '75.5'))
          .add(item('c', category: CostKind.shipping, price: '400'))
          .add(
            item('d', category: CostKind.accessory, qty: '3', price: '12.25'),
          );
      expect(sheet.subtotal, tl('712.25'));
      expect(sheet.totalOf(CostKind.material), tl('200'));
      expect(sheet.totalOf(CostKind.labor), tl('75.5'));
      expect(sheet.totalOf(CostKind.shipping), tl('400'));
      expect(sheet.totalOf(CostKind.accessory), tl('36.75'));
      expect(sheet.totalOf(CostKind.other), Money.zero);
    });

    test('JSON gidiş-dönüş', () {
      final sheet = const CostSheet().add(item('a')).add(item('b'));
      final back = CostSheet.fromJson(sheet.toJson());
      expect(back.toJson(), sheet.toJson());
    });
  });

  group('Ek maliyetler hesap sonucuna aktarılır', () {
    test('ana tutar + ek kalemler + KDV', () {
      final extras = const CostSheet()
          .add(
            item(
              'n',
              name: 'Nakliye',
              category: CostKind.shipping,
              unit: CostUnit.service,
              price: '500',
            ),
          )
          .add(
            item(
              'm',
              name: 'Montaj',
              category: CostKind.labor,
              qty: '2',
              unit: CostUnit.hour,
              price: '300',
            ),
          );
      final r = const MeasurementCalculator().calculate(
        MeasurementInput(
          type: MeasurementType.area,
          length: d('2'),
          width: d('1'),
          unitPrice: tl('1000'),
          vatPercent: d('20'),
          extras: extras,
        ),
      );
      final p = r.price!;
      expect(p.lines.map((l) => l.label), ['Alan', 'Nakliye', 'Montaj']);
      expect(p.subtotal, tl('3100')); // 2000 + 500 + 600
      expect(p.totalOf(CostKind.shipping), tl('500'));
      expect(p.totalOf(CostKind.labor), tl('600'));
      expect(p.vat, tl('620'));
      expect(p.grandTotal, tl('3720'));
      expect(
        r.steps,
        contains('Nakliye tutarı = 1 hizmet × ₺500,00/hizmet = ₺500,00'),
      );
    });

    test('birim fiyat yoksa yalnızca ek kalemler fiyatlanır', () {
      final r = const MeasurementCalculator().calculate(
        MeasurementInput(
          type: MeasurementType.length,
          length: d('3'),
          extras: const CostSheet().add(item('a', price: '250')),
        ),
      );
      expect(r.price!.lines, hasLength(1));
      expect(r.price!.subtotal, tl('250'));
    });

    test('hatalı ek kalem hesabı durdurur', () {
      expect(
        () => const MeasurementCalculator().calculate(
          MeasurementInput(
            type: MeasurementType.length,
            length: d('3'),
            extras: const CostSheet().add(item('a', qty: '0')),
          ),
        ),
        throwsA(isA<CalculationException>()),
      );
    });
  });
}
