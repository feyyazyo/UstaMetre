import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/money.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);

  group('Money', () {
    test('0,1 + 0,2 tam olarak 0,3 eder (kayan nokta hatası yok)', () {
      final sum = Money.fromDecimal(d('0.1')) + Money.fromDecimal(d('0.2'));
      expect(sum, Money.fromDecimal(d('0.3')));
      expect(sum.kurus, BigInt.from(30));
    });

    test('kuruşa yarım yukarı yuvarlar', () {
      expect(Money.fromDecimal(d('1.005')).kurus, BigInt.from(101));
      expect(Money.fromDecimal(d('1.004')).kurus, BigInt.from(100));
      expect(Money.fromDecimal(d('-1.005')).kurus, BigInt.from(-101));
    });

    test('çarpma kuruşa yuvarlanır', () {
      final price = Money.fromDecimal(d('333.33'));
      expect(price.multiply(d('3')), Money.fromDecimal(d('999.99')));
      expect(price.multiply(d('1.5')).kurus, BigInt.from(50000)); // 499.995
    });

    test('yüzde hesabı', () {
      final net = Money.fromDecimal(d('1000'));
      expect(net.percent(d('20')), Money.fromDecimal(d('200')));
      expect(
        Money.fromDecimal(d('99.99')).percent(d('18')).kurus,
        BigInt.from(1800), // 17.9982 → 18,00
      );
    });

    test('büyük tutarlarda hassasiyet kaybı yok', () {
      final big = Money.fromDecimal(d('9007199254740993.01'));
      expect(big.amount, d('9007199254740993.01'));
    });

    test('Türkçe biçimlendirme', () {
      expect(Money.fromDecimal(d('1250.5')).format(), '₺1.250,50');
      expect(Money.fromDecimal(d('0.07')).format(), '₺0,07');
      expect(Money.fromDecimal(d('1234567.89')).format(), '₺1.234.567,89');
      expect(Money.fromDecimal(d('-12')).format(), '-₺12,00');
      expect(Money.zero.format(), '₺0,00');
    });
  });
}
