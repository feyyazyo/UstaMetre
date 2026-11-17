import 'package:decimal/decimal.dart';

import '../calculator.dart';
import '../measurement.dart';
import '../money.dart';

/// Dikdörtgen yüzey: en × boy × adet, isteğe bağlı fire ve m² birim fiyatı.
///
/// Birçok meslek grubunun (mermer, seramik, boya, alçıpan…) ortak temel
/// hesabıdır. Meslek modülleri bu yapı taşının üzerine kurulacaktır.
final class RectangleAreaInput {
  const RectangleAreaInput({
    required this.width,
    required this.height,
    this.quantity = 1,
    this.wastePercent,
    this.unitPricePerSquareMeter,
  });

  final Length width;
  final Length height;
  final int quantity;

  /// Fire yüzdesi (ör. 10 → %10). Verilmezse 0 kabul edilir.
  final Decimal? wastePercent;
  final Money? unitPricePerSquareMeter;
}

final class RectangleAreaResult {
  const RectangleAreaResult({
    required this.netArea,
    required this.totalArea,
    this.totalPrice,
  });

  /// Fire hariç toplam alan.
  final Area netArea;

  /// Fire dahil toplam alan.
  final Area totalArea;

  /// Birim fiyat verildiyse fire dahil toplam fiyat.
  final Money? totalPrice;
}

final class RectangleAreaCalculator
    implements Calculator<RectangleAreaInput, RectangleAreaResult> {
  const RectangleAreaCalculator();

  @override
  String get id => 'manual.rectangle_area';

  @override
  RectangleAreaResult calculate(RectangleAreaInput input) {
    if (input.width.meters <= Decimal.zero ||
        input.height.meters <= Decimal.zero) {
      throw const CalculationException('En ve boy sıfırdan büyük olmalıdır.');
    }
    if (input.quantity < 1) {
      throw const CalculationException('Adet en az 1 olmalıdır.');
    }
    final waste = input.wastePercent ?? Decimal.zero;
    if (waste < Decimal.zero) {
      throw const CalculationException('Fire oranı negatif olamaz.');
    }
    final price = input.unitPricePerSquareMeter;
    if (price != null && price.isNegative) {
      throw const CalculationException('Birim fiyat negatif olamaz.');
    }

    final net = (input.width * input.height).times(
      Decimal.fromInt(input.quantity),
    );
    final wasteFactor =
        Decimal.one +
        (waste / Decimal.fromInt(100)).toDecimal(scaleOnInfinitePrecision: 10);
    final total = net.times(wasteFactor);

    return RectangleAreaResult(
      netArea: net,
      totalArea: total,
      totalPrice: price?.multiply(total.squareMeters),
    );
  }
}
