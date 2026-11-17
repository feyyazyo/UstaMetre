import 'package:decimal/decimal.dart';

/// Kuruş hassasiyetinde, kayan nokta hatası içermeyen para değeri.
///
/// Değer dahili olarak tam sayı kuruş ([BigInt]) olarak tutulur.
final class Money implements Comparable<Money> {
  const Money._(this.kurus);

  /// Tam sayı kuruş cinsinden değer.
  final BigInt kurus;

  static final Money zero = Money._(BigInt.zero);

  factory Money.fromKurus(int kurus) => Money._(BigInt.from(kurus));

  factory Money.fromKurusBig(BigInt kurus) => Money._(kurus);

  /// [amount] TL cinsinden değerdir; kuruşa yarım yukarı (sıfırdan uzağa)
  /// yuvarlanır.
  factory Money.fromDecimal(Decimal amount) {
    final rounded = (amount * Decimal.fromInt(100)).round();
    return Money._(rounded.toBigInt());
  }

  /// TL cinsinden kesin değer.
  Decimal get amount =>
      (Decimal.fromBigInt(kurus) / Decimal.fromInt(100)).toDecimal();

  Money operator +(Money other) => Money._(kurus + other.kurus);
  Money operator -(Money other) => Money._(kurus - other.kurus);

  /// Miktar ile çarpar (ör. m² × birim fiyat) ve kuruşa yuvarlar.
  Money multiply(Decimal factor) => Money.fromDecimal(amount * factor);

  /// Yüzde uygular: `percent(Decimal.fromInt(20))` → %20'si.
  Money percent(Decimal rate) => Money.fromDecimal(
    (amount * rate / Decimal.fromInt(100)).toDecimal(
      scaleOnInfinitePrecision: 10,
    ),
  );

  bool get isNegative => kurus.isNegative;

  bool operator <(Money other) => kurus < other.kurus;
  bool operator >(Money other) => kurus > other.kurus;
  bool operator <=(Money other) => kurus <= other.kurus;
  bool operator >=(Money other) => kurus >= other.kurus;

  /// Türkçe biçim: `₺1.250,50`
  String format({String symbol = '₺'}) {
    final negative = kurus.isNegative;
    final abs = kurus.abs();
    final lira = abs ~/ BigInt.from(100);
    final kr = (abs % BigInt.from(100)).toInt().toString().padLeft(2, '0');
    final grouped = _groupThousands(lira.toString());
    return '${negative ? '-' : ''}$symbol$grouped,$kr';
  }

  static String _groupThousands(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  int compareTo(Money other) => kurus.compareTo(other.kurus);

  @override
  bool operator ==(Object other) => other is Money && other.kurus == kurus;

  @override
  int get hashCode => kurus.hashCode;

  @override
  String toString() => format();
}
