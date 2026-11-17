import 'package:decimal/decimal.dart';

import '../calculation_result.dart';
import '../calculator.dart';
import '../costing/cost_sheet.dart';
import '../measurement.dart';
import '../money.dart';
import '../number_format.dart';
import '../price_steps.dart';
import '../pricing.dart';
import 'validation.dart';

final class MarbleCountertopInput {
  const MarbleCountertopInput({
    this.unit = LengthUnit.centimeter,
    this.length,
    this.depth,
    this.quantity = 1,
    this.wastePercent,
    this.materialPricePerSquareMeter,
    this.laborPricePerLinearMeter,
    this.vatPercent,
    this.extras = const CostSheet(),
    this.discount,
  });

  final LengthUnit unit;

  /// Tezgâhın uzunluğu (duvar boyunca).
  final Decimal? length;

  /// Tezgâhın derinliği (genişliği).
  final Decimal? depth;
  final int quantity;

  /// Malzemeye uygulanan fire (kesim kaybı) yüzdesi.
  final Decimal? wastePercent;

  /// Taş/plaka fiyatı (₺/m²); fireli alan üzerinden uygulanır.
  final Money? materialPricePerSquareMeter;

  /// İşçilik fiyatı (₺/mtül); tezgâh uzunluğu üzerinden uygulanır.
  final Money? laborPricePerLinearMeter;
  final Decimal? vatPercent;
  final CostSheet extras;
  final Discount? discount;
}

/// Mermer ve granit dikdörtgen tezgâh hesabı.
///
/// * Net alan = uzunluk × derinlik × adet (m²)
/// * Fireli alan = net alan × (1 + fire/100)
/// * Metre tül = uzunluk × adet (mtül)
/// * Malzeme tutarı = fireli alan × m² fiyatı
/// * İşçilik tutarı = metre tül × mtül işçilik fiyatı
/// * Ara toplam = malzeme + işçilik; KDV ve genel toplam
final class MarbleCountertopCalculator
    implements Calculator<MarbleCountertopInput, CalculationResult> {
  const MarbleCountertopCalculator();

  @override
  String get id => 'marble.countertop';

  @override
  CalculationResult calculate(MarbleCountertopInput input) {
    requireQuantity(input.quantity);
    final waste = requirePercent(input.wastePercent, 'Fire oranı');
    final vatRate = requirePercent(input.vatPercent, 'KDV oranı');
    requireNonNegativePrice(
      input.materialPricePerSquareMeter,
      'Malzeme fiyatı',
    );
    requireNonNegativePrice(input.laborPricePerLinearMeter, 'İşçilik fiyatı');

    final l = requirePositiveLength(input.length, input.unit, 'Uzunluk');
    final d = requirePositiveLength(input.depth, input.unit, 'Derinlik');
    final q = Decimal.fromInt(input.quantity);
    final qText = input.quantity > 1 ? ' × ${input.quantity} adet' : '';

    String m(Decimal v, [String u = 'm']) =>
        formatQuantity(v, u, maxDecimals: 6);

    final steps = <String>[];
    final conversion = conversionStep(input.unit, [
      ('Uzunluk', input.length!, l),
      ('Derinlik', input.depth!, d),
    ]);
    if (conversion != null) steps.add(conversion);

    final netArea = (l * d).times(q).squareMeters;
    steps.add(
      'Net alan = ${m(l.meters)} × ${m(d.meters)}$qText = ${m(netArea, 'm²')}',
    );

    final wasteArea = netArea * percentFactor(waste);
    if (waste > Decimal.zero) {
      steps.add(
        'Fireli alan (${formatPercent(waste)}) = ${m(netArea, 'm²')} × '
        '${formatDecimal(percentFactor(waste))} = ${m(wasteArea, 'm²')}',
      );
    }

    final linear = l.meters * q;
    steps.add('Metre tül = ${m(l.meters)}$qText = ${m(linear, 'mtül')}');

    final figures = [
      ResultFigure(label: 'Net alan', value: netArea, unit: 'm²'),
      if (waste > Decimal.zero)
        ResultFigure(
          label: 'Fireli alan (${formatPercent(waste)})',
          value: wasteArea,
          unit: 'm²',
          highlighted: true,
        ),
      ResultFigure(
        label: 'Metre tül',
        value: linear,
        unit: 'mtül',
        highlighted: waste == Decimal.zero,
      ),
    ];

    final lines = <CostLine>[
      if (input.materialPricePerSquareMeter case final price?)
        CostLine(
          label: 'Malzeme',
          kind: CostKind.material,
          quantity: wasteArea,
          unit: 'm²',
          unitPrice: price,
        ),
      if (input.laborPricePerLinearMeter case final price?)
        CostLine(
          label: 'İşçilik',
          kind: CostKind.labor,
          quantity: linear,
          unit: 'mtül',
          unitPrice: price,
        ),
    ];

    final price = buildPriceSummary(
      lines: lines,
      steps: steps,
      extras: input.extras,
      vatPercent: vatRate,
      discount: input.discount,
    );

    return CalculationResult(figures: figures, price: price, steps: steps);
  }
}
