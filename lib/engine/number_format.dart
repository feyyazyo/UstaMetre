import 'package:decimal/decimal.dart';

/// [value] değerini Türkçe biçimde yazar: binlik ayırıcı nokta, ondalık
/// ayırıcı virgül. En fazla [maxDecimals] hane gösterilir (yarım yukarı
/// yuvarlanır), sondaki sıfırlar atılır.
///
/// `formatDecimal(Decimal.parse('1250.75'))` → `1.250,75`
String formatDecimal(Decimal value, {int maxDecimals = 4}) {
  final rounded = value.round(scale: maxDecimals);
  final negative = rounded < Decimal.zero;
  final text = rounded.abs().toStringAsFixed(maxDecimals);

  final parts = text.split('.');
  final integerPart = _groupThousands(parts[0]);
  var fraction = parts.length > 1 ? parts[1] : '';
  fraction = fraction.replaceFirst(RegExp(r'0+$'), '');

  final body = fraction.isEmpty ? integerPart : '$integerPart,$fraction';
  return negative ? '-$body' : body;
}

/// Gösterilen değer yuvarlandıysa `true` döner (arayüzde "≈" için).
bool isRoundedForDisplay(Decimal value, {int maxDecimals = 4}) =>
    value.round(scale: maxDecimals) != value;

/// Değeri birimiyle yazar; yuvarlama varsa başına `≈` ekler.
/// `formatQuantity(Decimal.parse('1.584'), 'm²')` → `1,584 m²`
String formatQuantity(Decimal value, String unit, {int maxDecimals = 4}) {
  final prefix = isRoundedForDisplay(value, maxDecimals: maxDecimals)
      ? '≈'
      : '';
  return '$prefix${formatDecimal(value, maxDecimals: maxDecimals)} $unit';
}

/// Yüzde biçimi: `%10`, `%7,5`
String formatPercent(Decimal value) => '%${formatDecimal(value)}';

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
