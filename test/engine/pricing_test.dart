import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/calculator.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/engine/pricing.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);
  Money tl(String s) => Money.fromDecimal(d(s));

  CostLine line(
    String qty,
    String price, [
    CostKind kind = CostKind.material,
  ]) => CostLine(
    label: 'Kalem',
    kind: kind,
    quantity: d(qty),
    unit: 'm²',
    unitPrice: tl(price),
  );

  group('Fiyat ve KDV', () {
    test('satır tutarı kuruşa yuvarlanır', () {
      expect(line('1.705', '3200').amount, tl('5456'));
      expect(line('0.333', '10').amount, tl('3.33'));
      expect(line('0.335', '10').amount, tl('3.35'));
      expect(line('0.0005', '10').amount, tl('0.01')); // 0,005 → 0,01
    });

    test('%20 KDV', () {
      final p = PriceSummary.fromLines([
        line('1', '1000'),
      ], vatPercent: d('20'));
      expect(p.subtotal, tl('1000'));
      expect(p.vat, tl('200'));
      expect(p.grandTotal, tl('1200'));
    });

    test('%10 ve %1 KDV oranları', () {
      expect(
        PriceSummary.fromLines([line('1', '99.99')], vatPercent: d('10')).vat,
        tl('10'), // 9,999 → 10,00
      );
      expect(
        PriceSummary.fromLines([line('1', '250')], vatPercent: d('1')).vat,
        tl('2.5'),
      );
    });

    test('KDV kuruş yuvarlaması ve toplam tutarlılığı', () {
      final p = PriceSummary.fromLines([
        line('1', '33.33'),
      ], vatPercent: d('20'));
      expect(p.vat, tl('6.67')); // 6,666 → 6,67
      expect(p.grandTotal, tl('40'));
      expect(p.subtotal + p.vat, p.grandTotal);
    });

    test('KDV verilmezse %0', () {
      final p = PriceSummary.fromLines([line('2', '50')]);
      expect(p.vat, Money.zero);
      expect(p.grandTotal, tl('100'));
    });

    test('malzeme ve işçilik toplamları ayrı ayrı', () {
      final p = PriceSummary.fromLines([
        line('2', '100'),
        line('1.5', '40', CostKind.labor),
        line('1', '25.5'),
      ], vatPercent: d('20'));
      expect(p.totalOf(CostKind.material), tl('225.5'));
      expect(p.totalOf(CostKind.labor), tl('60'));
      expect(p.totalOf(CostKind.other), Money.zero);
      expect(p.subtotal, tl('285.5'));
      expect(p.vat, tl('57.1'));
      expect(p.grandTotal, tl('342.6'));
    });

    test('çok sayıda küçük tutarda kayan nokta hatası birikmez', () {
      final p = PriceSummary.fromLines([
        for (var i = 0; i < 1000; i++) line('1', '0.1'),
      ]);
      expect(p.subtotal, tl('100'));
    });
  });

  group('İndirim', () {
    test('yüzde indirim KDV matrahını düşürür', () {
      final p = PriceSummary.fromLines(
        [line('1', '1000')],
        vatPercent: d('20'),
        discount: PercentDiscount(d('10')),
      );
      expect(p.subtotal, tl('1000'));
      expect(p.discount, tl('100'));
      expect(p.taxBase, tl('900'));
      expect(p.vat, tl('180'));
      expect(p.grandTotal, tl('1080'));
    });

    test('tutar indirimi', () {
      final p = PriceSummary.fromLines(
        [line('1', '1000')],
        vatPercent: d('20'),
        discount: AmountDiscount(tl('250.5')),
      );
      expect(p.taxBase, tl('749.5'));
      expect(p.vat, tl('149.9'));
      expect(p.grandTotal, tl('899.4'));
    });

    test('yüzde indirim kuruşa yuvarlanır ve toplam tutarlı kalır', () {
      final p = PriceSummary.fromLines(
        [line('1', '33.33')],
        vatPercent: d('18'),
        discount: PercentDiscount(d('7.5')),
      );
      expect(p.discount, tl('2.5')); // 2,49975 → 2,50
      expect(p.taxBase, tl('30.83'));
      expect(p.vat, tl('5.55')); // 5,5494 → 5,55
      expect(p.grandTotal, p.subtotal - p.discount + p.vat);
    });

    test('geçersiz indirimler reddedilir', () {
      expect(
        () => PercentDiscount(d('101')),
        throwsA(isA<CalculationException>()),
      );
      expect(
        () => AmountDiscount(tl('-1')),
        throwsA(isA<CalculationException>()),
      );
      expect(
        () => PriceSummary.fromLines([
          line('1', '100'),
        ], discount: AmountDiscount(tl('100.01'))),
        throwsA(isA<CalculationException>()),
      );
    });

    test('%100 indirim sıfır toplam verir', () {
      final p = PriceSummary.fromLines(
        [line('1', '100')],
        vatPercent: d('20'),
        discount: PercentDiscount(d('100')),
      );
      expect(p.grandTotal, Money.zero);
    });
  });

  group('KDV oranı ve gösterimi', () {
    test('KDV oranı değiştirilebilir', () {
      for (final (rate, vat) in [
        ('0', '0'),
        ('1', '10'),
        ('10', '100'),
        ('20', '200'),
      ]) {
        final p = PriceSummary.fromLines([
          line('1', '1000'),
        ], vatPercent: d(rate));
        expect(p.vat, tl(vat), reason: '%$rate');
      }
    });

    test('aralık dışı KDV reddedilir', () {
      expect(
        () => PriceSummary.fromLines([line('1', '1')], vatPercent: d('120')),
        throwsA(isA<CalculationException>()),
      );
    });

    test('KDV dahil / hariç satır gösterimi', () {
      final p = PriceSummary.fromLines([
        line('1', '99.99'),
      ], vatPercent: d('20'));
      final amount = p.lines.single.amount;
      expect(p.displayAmount(amount, VatDisplayMode.excluded), tl('99.99'));
      expect(
        p.displayAmount(amount, VatDisplayMode.included),
        tl('119.99'),
      ); // 119,988
    });

    test('JSON özeti kuruş olarak yazılır', () {
      final json = PriceSummary.fromLines(
        [line('2', '50')],
        vatPercent: d('20'),
        discount: PercentDiscount(d('10')),
      ).toJson();
      expect(json['subtotalKurus'], '10000');
      expect(json['discountKurus'], '1000');
      expect(json['vatKurus'], '1800');
      expect(json['grandTotalKurus'], '10800');
    });
  });

  test('indirim açıklaması Türkçe yüzde biçiminde', () {
    expect(PercentDiscount(d('7.5')).description, '%7,5');
    expect(AmountDiscount(tl('1250.5')).description, '₺1.250,50');
  });
}
