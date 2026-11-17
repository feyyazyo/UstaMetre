import 'package:decimal/decimal.dart';

import 'costing/cost_sheet.dart';
import 'number_format.dart';
import 'pricing.dart';

/// Fiyat satırlarını, ara toplamı, indirimi, KDV'yi ve genel toplamı
/// "Nasıl hesaplandı?" adımlarına ekler.
void addPriceSteps(List<String> steps, PriceSummary price) {
  for (final line in price.lines) {
    steps.add(
      '${line.label} tutarı = '
      '${formatQuantity(line.quantity, line.unit, maxDecimals: 6)} × '
      '${line.unitPrice.format()}/${line.unit} = ${line.amount.format()}',
    );
  }
  if (price.lines.length > 1) {
    steps.add(
      'Ara toplam = '
      '${price.lines.map((l) => l.amount.format()).join(' + ')} = '
      '${price.subtotal.format()}',
    );
  } else {
    steps.add('Ara toplam = ${price.subtotal.format()}');
  }
  if (price.hasDiscount) {
    final rule = price.discountRule;
    final how = rule is PercentDiscount
        ? '${price.subtotal.format()} × ${formatPercent(rule.percent)}'
        : 'sabit tutar';
    steps.add('İndirim = $how = ${price.discount.format()}');
    steps.add(
      'KDV matrahı = ${price.subtotal.format()} − ${price.discount.format()} '
      '= ${price.taxBase.format()}',
    );
  }
  if (price.vatPercent > Decimal.zero) {
    steps.add(
      'KDV ${formatPercent(price.vatPercent)} = '
      '${price.taxBase.format()} × ${formatPercent(price.vatPercent)} = '
      '${price.vat.format()}',
    );
  }
  steps.add(
    'Genel toplam = ${price.taxBase.format()} + ${price.vat.format()} = '
    '${price.grandTotal.format()}',
  );
}

/// Hesaplayıcının kendi satırlarına ek maliyet kalemlerini ekler, indirim ve
/// KDV uygular ve adımları yazar. Hiç satır yoksa `null` döner.
///
/// Ek kalemler doğrulanır; hatalıysa [CalculationException] fırlar.
PriceSummary? buildPriceSummary({
  required List<CostLine> lines,
  required List<String> steps,
  CostSheet extras = const CostSheet(),
  Decimal? vatPercent,
  Discount? discount,
}) {
  extras.validate();
  final all = [...lines, ...extras.toLines()];
  if (all.isEmpty) return null;
  final price = PriceSummary.fromLines(
    all,
    vatPercent: vatPercent,
    discount: discount,
  );
  addPriceSteps(steps, price);
  return price;
}
