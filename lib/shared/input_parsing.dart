import 'package:decimal/decimal.dart';

import '../engine/money.dart';
import '../engine/number_parser.dart';

const invalidNumberText = 'Geçerli bir sayı girin (ör. 1.250,75)';

/// Bir giriş alanının ayrıştırma sonucu: boşsa değer ve hata `null`.
typedef ParsedField<T> = ({T? value, String? error});

/// Türkçe sayı girişini ayrıştırır. Boş metin `null` değer döner.
ParsedField<Decimal> parseField(String text, {bool allowNegative = false}) {
  final raw = text.trim();
  if (raw.isEmpty) return (value: null, error: null);
  final value = parseDecimal(raw);
  if (value == null) return (value: null, error: invalidNumberText);
  if (!allowNegative && value < Decimal.zero) {
    return (value: null, error: 'Negatif değer girilemez');
  }
  return (value: value, error: null);
}

ParsedField<Money> parseMoneyField(String text) {
  final p = parseField(text);
  return (
    value: p.value == null ? null : Money.fromDecimal(p.value!),
    error: p.error,
  );
}

/// Tam sayı adet; boşsa [fallback].
ParsedField<int> parseCountField(String text, {int fallback = 1}) {
  final p = parseField(text);
  if (p.error != null) return (value: null, error: p.error);
  final v = p.value;
  if (v == null) return (value: fallback, error: null);
  if (!v.isInteger || v < Decimal.one) {
    return (value: null, error: 'Adet 1 veya daha büyük tam sayı olmalı');
  }
  return (value: v.toBigInt().toInt(), error: null);
}

/// Decimal değeri giriş alanına yazmak için Türkçe biçim (binlik ayırıcısız).
String decimalToInput(Decimal? value) =>
    value == null ? '' : value.toString().replaceAll('.', ',');

String moneyToInput(Money? value) =>
    value == null ? '' : decimalToInput(value.amount);
