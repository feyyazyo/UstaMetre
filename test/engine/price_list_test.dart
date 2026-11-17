import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/calculator.dart';
import 'package:ustametre/engine/calculators/measurement_calculator.dart';
import 'package:ustametre/engine/costing/cost_item.dart';
import 'package:ustametre/engine/costing/cost_sheet.dart';
import 'package:ustametre/engine/costing/price_list.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/engine/pricing.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);
  Money tl(String s) => Money.fromDecimal(d(s));
  final jan = DateTime.utc(2026, 1, 1);
  final jun = DateTime.utc(2026, 6, 1);
  final nov = DateTime.utc(2026, 11, 1);

  PriceListItem evye() => PriceListItem.create(
    id: 'evye',
    name: 'Evye montajı',
    category: CostKind.labor,
    unit: CostUnit.piece,
    price: tl('750'),
    at: jan,
  );

  group('PriceListItem', () {
    test('fiyat değişikliği geçmişe eklenir, üzerine yazılmaz', () {
      final item = evye().withPrice(tl('900'), at: jun);
      expect(item.price, tl('900'));
      expect(item.history.map((p) => p.price), [tl('750'), tl('900')]);
    });

    test('tarihteki fiyat sorgulanabilir', () {
      final item = evye()
          .withPrice(tl('900'), at: jun)
          .withPrice(tl('1000'), at: nov);
      expect(item.pointAt(DateTime.utc(2025, 12, 31)), isNull);
      expect(item.pointAt(jan)!.price, tl('750'));
      expect(item.pointAt(DateTime.utc(2026, 8, 15))!.price, tl('900'));
      expect(item.pointAt(DateTime.utc(2027))!.price, tl('1000'));
    });

    test('birim değişikliği de geçmişte tutulur', () {
      final item = evye().withPrice(tl('120'), at: jun, unit: CostUnit.hour);
      expect(item.unit, CostUnit.hour);
      expect(item.pointAt(jan)!.unit, CostUnit.piece);
    });

    test('aynı fiyat ve birim yeni kayıt oluşturmaz', () {
      expect(evye().withPrice(tl('750'), at: jun).history, hasLength(1));
    });

    test('geçmişe dönük fiyat ve hatalı girişler reddedilir', () {
      final item = evye().withPrice(tl('900'), at: jun);
      expect(
        () => item.withPrice(tl('950'), at: jan),
        throwsA(isA<CalculationException>()),
      );
      expect(
        () => item.withPrice(tl('-1'), at: nov),
        throwsA(isA<CalculationException>()),
      );
      expect(
        () => PriceListItem.create(
          id: 'x',
          name: ' ',
          category: CostKind.other,
          unit: CostUnit.piece,
          price: tl('1'),
          at: jan,
        ),
        throwsA(isA<CalculationException>()),
      );
    });

    test('ad değişikliği fiyat geçmişini korur', () {
      final item = evye()
          .withPrice(tl('900'), at: jun)
          .rename(name: 'Evye takma');
      expect(item.name, 'Evye takma');
      expect(item.history, hasLength(2));
    });
  });

  group('Eski hesaplamaların korunması', () {
    test(
      'listeden eklenen kalem fiyatı kopyalar; liste değişince bozulmaz',
      () {
        var list = const PriceList().add(evye());
        final costItem = list
            .byId('evye')!
            .toCostItem(id: 'c1', quantity: d('2'));
        expect(costItem.total, tl('1500'));
        expect(costItem.source!.effectiveFrom, jan);

        list = list.updatePrice('evye', tl('1200'), at: nov);
        expect(list.byId('evye')!.price, tl('1200'));

        // Eski kalem ve onu kullanan hesap aynı kalır.
        expect(costItem.unitPrice, tl('750'));
        expect(costItem.total, tl('1500'));
        final result = const MeasurementCalculator().calculate(
          MeasurementInput(
            type: MeasurementType.piece,
            extras: const CostSheet().add(costItem),
          ),
        );
        expect(result.price!.subtotal, tl('1500'));

        // Kaydedilmiş (JSON) kalem de aynı kalır.
        final restored = CostItem.fromJson(costItem.toJson());
        expect(restored.total, tl('1500'));

        // Yeni eklenen kalem yeni fiyatı alır.
        expect(list.byId('evye')!.toCostItem(id: 'c2').unitPrice, tl('1200'));
      },
    );

    test('kaynak tarihinden o günkü fiyat bulunabilir', () {
      final list = const PriceList()
          .add(evye())
          .updatePrice('evye', tl('1200'), at: nov);
      final source = PriceSource(priceListItemId: 'evye', effectiveFrom: jan);
      expect(
        list.byId(source.priceListItemId)!.pointAt(source.effectiveFrom)!.price,
        tl('750'),
      );
    });
  });

  group('PriceList', () {
    test('ekleme, kategoriye göre listeleme, silme', () {
      final list = const PriceList()
          .add(evye())
          .add(
            PriceListItem.create(
              id: 'nakliye',
              name: 'Şehir içi nakliye',
              category: CostKind.shipping,
              unit: CostUnit.service,
              price: tl('600'),
              at: jan,
            ),
          );
      expect(list.byCategory(CostKind.labor).single.id, 'evye');
      expect(list.byCategory(CostKind.shipping).single.id, 'nakliye');
      expect(() => list.add(evye()), throwsArgumentError);
      expect(list.remove('evye').items.single.id, 'nakliye');
    });

    test('JSON gidiş-dönüş geçmişi korur', () {
      final list = const PriceList()
          .add(evye())
          .updatePrice('evye', tl('900.5'), at: jun, unit: CostUnit.hour);
      final back = PriceList.fromJson(list.toJson());
      expect(back.toJson(), list.toJson());
      expect(back.byId('evye')!.pointAt(jan)!.price, tl('750'));
      expect(list.toJson()['version'], PriceList.schemaVersion);
    });
  });
}
