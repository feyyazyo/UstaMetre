import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
