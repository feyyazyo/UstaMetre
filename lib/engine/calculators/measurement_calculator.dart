import 'package:decimal/decimal.dart';

import '../calculation_result.dart';
import '../calculator.dart';
import '../measurement.dart';
import '../money.dart';
import '../number_format.dart';
import '../pricing.dart';
import 'validation.dart';

/// Tüm meslek gruplarında kullanılabilen genel hesap türleri.
enum MeasurementType {
  length('Uzunluk', 'm'),
  area('Alan', 'm²'),
  volume('Hacim', 'm³'),
  linearMeter('Metre tül', 'mtül'),
  perimeter('Çevre', 'm'),
  piece('Adet', 'adet'),
  manual('Manuel', 'birim');

  const MeasurementType(this.label, this.unitSymbol);

  final String label;

  /// Sonucun birimi (birim fiyat bu birim başınadır).
  final String unitSymbol;

  bool get needsLength => switch (this) {
    length || area || volume || linearMeter || perimeter => true,
    piece || manual => false,
  };

  bool get needsWidth => this == area || this == volume || this == perimeter;

  bool get needsHeight => this == volume;

  bool get usesLengthUnit => needsLength;
}

final class MeasurementInput {
  const MeasurementInput({
    required this.type,
    this.unit = LengthUnit.meter,
    this.length,
    this.width,
    this.height,
    this.quantity = 1,
    this.manualAmount,
    this.wastePercent,
    this.unitPrice,
    this.vatPercent,
  });

  final MeasurementType type;

  /// [length], [width] ve [height] bu birimdedir.
  final LengthUnit unit;
  final Decimal? length;
  final Decimal? width;
  final Decimal? height;

  /// Aynı ölçüden kaç tane olduğu (tam sayı, en az 1).
  final int quantity;

  /// Yalnızca [MeasurementType.manual] için: bir adetin miktarı.
  final Decimal? manualAmount;

  final Decimal? wastePercent;

  /// Sonuç biriminin (m, m², m³, mtül, adet, birim) birim fiyatı.
  final Money? unitPrice;
  final Decimal? vatPercent;
}

/// Uzunluk, alan, hacim, metre tül, çevre, adet ve manuel hesap.
///
/// * Fire, net miktara yüzde olarak eklenir. Adet hesabında fireli miktar
///   yukarı tam sayıya yuvarlanır (yarım parça alınamaz).
/// * Birim fiyat verilirse tutar = fireli miktar × birim fiyat (kuruşa
///   yuvarlanır); KDV ara toplam üzerinden hesaplanır.
final class MeasurementCalculator
    implements Calculator<MeasurementInput, CalculationResult> {
  const MeasurementCalculator();

  @override
  String get id => 'generic.measurement';

  @override
  CalculationResult calculate(MeasurementInput input) {
    final type = input.type;
    final unit = input.unit;
    requireQuantity(input.quantity);
    final waste = requirePercent(input.wastePercent, 'Fire oranı');
    final vatRate = requirePercent(input.vatPercent, 'KDV oranı');
    requireNonNegativePrice(input.unitPrice, 'Birim fiyat');

    final steps = <String>[];
    final q = Decimal.fromInt(input.quantity);
    final qText = input.quantity > 1 ? ' × ${input.quantity} adet' : '';
    final symbol = type.unitSymbol;

    Length? l, w, h;
    if (type.needsLength) {
      l = requirePositiveLength(input.length, unit, 'Uzunluk');
    }
    if (type.needsWidth) {
      w = requirePositiveLength(input.width, unit, 'Genişlik');
    }
    if (type.needsHeight) {
      h = requirePositiveLength(input.height, unit, 'Yükseklik');
    }
    final conversion = conversionStep(unit, [
      if (l != null) ('Uzunluk', input.length!, l),
      if (w != null) ('Genişlik', input.width!, w),
      if (h != null) ('Yükseklik', input.height!, h),
    ]);
    if (conversion != null) steps.add(conversion);

    String m(Decimal v, [String u = 'm']) =>
        formatQuantity(v, u, maxDecimals: 6);

    final Decimal net;
    switch (type) {
      case MeasurementType.length:
        net = l!.meters * q;
        steps.add('Uzunluk = ${m(l.meters)}$qText = ${m(net)}');
      case MeasurementType.linearMeter:
        net = l!.meters * q;
        steps.add(
          'Metre tül, uzunluk boyunca ölçülen doğrusal metredir: '
          '${m(l.meters)}$qText = ${m(net, symbol)}',
        );
      case MeasurementType.area:
        net = (l! * w!).times(q).squareMeters;
        steps.add(
          'Alan = ${m(l.meters)} × ${m(w.meters)}$qText = ${m(net, symbol)}',
        );
      case MeasurementType.volume:
        net = (l! * w! * h!).times(q).cubicMeters;
        steps.add(
          'Hacim = ${m(l.meters)} × ${m(w.meters)} × ${m(h.meters)}$qText'
          ' = ${m(net, symbol)}',
        );
      case MeasurementType.perimeter:
        net = (l!.meters + w!.meters) * Decimal.fromInt(2) * q;
        steps.add(
          'Çevre = 2 × (${m(l.meters)} + ${m(w.meters)})$qText = ${m(net)}',
        );
      case MeasurementType.piece:
        net = q;
        steps.add('Adet = ${input.quantity}');
      case MeasurementType.manual:
        final amount = input.manualAmount;
        if (amount == null) throw const CalculationException('Miktar girin.');
        if (amount <= Decimal.zero) {
          throw const CalculationException('Miktar sıfırdan büyük olmalıdır.');
        }
        net = amount * q;
        steps.add('Miktar = ${m(amount, symbol)}$qText = ${m(net, symbol)}');
    }

    var total = net;
    if (waste > Decimal.zero) {
      final exact = net * percentFactor(waste);
      if (type == MeasurementType.piece) {
        total = exact.ceil();
        steps.add(
          'Fire ${formatPercent(waste)}: ${input.quantity} × '
          '${formatDecimal(percentFactor(waste))} = ${formatDecimal(exact)} '
          '→ yukarı yuvarlanarak ${formatDecimal(total)} adet',
        );
      } else {
        total = exact;
        steps.add(
          'Fire ${formatPercent(waste)}: ${m(net, symbol)} × '
          '${formatDecimal(percentFactor(waste))} = ${m(total, symbol)}',
        );
      }
    }

    final figures = <ResultFigure>[
      ResultFigure(
        label: 'Net ${type.label.toLowerCase()}',
        value: net,
        unit: symbol,
      ),
      if (waste > Decimal.zero) ...[
        ResultFigure(
          label: 'Fire (${formatPercent(waste)})',
          value: total - net,
          unit: symbol,
        ),
        ResultFigure(
          label: 'Fireli toplam',
          value: total,
          unit: symbol,
          highlighted: true,
        ),
      ],
    ];
    if (waste == Decimal.zero) {
      figures[0] = ResultFigure(
        label: figures[0].label,
        value: net,
        unit: symbol,
        highlighted: true,
      );
    }

    PriceSummary? price;
    final unitPrice = input.unitPrice;
    if (unitPrice != null) {
      price = PriceSummary.fromLines([
        CostLine(
          label: type.label,
          kind: CostKind.material,
          quantity: total,
          unit: symbol,
          unitPrice: unitPrice,
        ),
      ], vatPercent: vatRate);
      addPriceSteps(steps, price);
    }

    return CalculationResult(figures: figures, price: price, steps: steps);
  }
}

/// Fiyat satırlarını, ara toplamı, KDV'yi ve genel toplamı adımlara ekler.
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
  if (price.vatPercent > Decimal.zero) {
    steps.add(
      'KDV ${formatPercent(price.vatPercent)} = '
      '${price.subtotal.format()} × ${formatPercent(price.vatPercent)} = '
      '${price.vat.format()}',
    );
  }
  steps.add(
    'Genel toplam = ${price.subtotal.format()} + ${price.vat.format()} = '
    '${price.grandTotal.format()}',
  );
}
