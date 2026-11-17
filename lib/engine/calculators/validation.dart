import 'package:decimal/decimal.dart';

import '../calculator.dart';
import '../measurement.dart';
import '../money.dart';
import '../number_format.dart';

/// Hesaplayıcıların ortak doğrulama ve dönüşüm yardımcıları.

final Decimal hundred = Decimal.fromInt(100);

/// Zorunlu, pozitif bir ölçüyü metreye çevirir.
Length requirePositiveLength(Decimal? value, LengthUnit unit, String name) {
  if (value == null) throw CalculationException('$name girin.');
  if (value <= Decimal.zero) {
    throw CalculationException('$name sıfırdan büyük olmalıdır.');
  }
  return Length(value, unit);
}

void requireQuantity(int quantity) {
  if (quantity < 1) {
    throw const CalculationException('Adet en az 1 olmalıdır.');
  }
}

/// 0–100 arası yüzde (fire, KDV). `null` → 0.
Decimal requirePercent(Decimal? value, String name) {
  final v = value ?? Decimal.zero;
  if (v < Decimal.zero || v > hundred) {
    throw CalculationException('$name %0 ile %100 arasında olmalıdır.');
  }
  return v;
}

void requireNonNegativePrice(Money? price, String name) {
  if (price != null && price.isNegative) {
    throw CalculationException('$name negatif olamaz.');
  }
}

/// `1 + yüzde/100`
Decimal percentFactor(Decimal percent) =>
    Decimal.one + (percent / hundred).toDecimal();

/// Birim metreden farklıysa "120 cm = 1,2 m" biçiminde dönüşüm adımı.
String? conversionStep(
  LengthUnit unit,
  List<(String name, Decimal value, Length length)> dims,
) {
  if (unit == LengthUnit.meter || dims.isEmpty) return null;
  final parts = dims
      .map(
        (d) =>
            '${d.$1} ${formatDecimal(d.$2)} ${unit.symbol} = '
            '${formatQuantity(d.$3.meters, 'm', maxDecimals: 6)}',
      )
      .join('; ');
  return 'Ölçüler metreye çevrildi: $parts';
}
