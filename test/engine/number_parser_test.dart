import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/number_parser.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);

  group('parseDecimal', () {
    test('Türkçe ondalık virgülü', () {
      expect(parseDecimal('12,5'), d('12.5'));
      expect(parseDecimal('0,1'), d('0.1'));
    });

    test('binlik nokta ve ondalık virgül', () {
      expect(parseDecimal('1.250,75'), d('1250.75'));
      expect(parseDecimal('1.000.000,5'), d('1000000.5'));
    });

    test('tek noktadan sonra 3 hane binlik ayırıcıdır', () {
      expect(parseDecimal('1.250'), d('1250'));
    });

    test('tek noktadan sonra 1-2 hane ondalıktır', () {
      expect(parseDecimal('12.5'), d('12.5'));
      expect(parseDecimal('12.75'), d('12.75'));
    });

    test('fiyat girişleri', () {
      expect(parseDecimal('3.200'), d('3200'));
      expect(parseDecimal('3.200,50'), d('3200.5'));
      expect(parseDecimal('99,99'), d('99.99'));
      expect(parseDecimal('0,005'), d('0.005'));
    });

    test('ölçü girişleri', () {
      expect(parseDecimal('62'), d('62'));
      expect(parseDecimal('250,5'), d('250.5'));
      expect(parseDecimal('1.250'), d('1250'));
    });

    test('boşlukları yok sayar', () {
      expect(parseDecimal(' 1 250,5 '), d('1250.5'));
    });

    test('geçersiz girdide null döner', () {
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('abc'), isNull);
      expect(parseDecimal('1,2,3'), isNull);
      expect(parseDecimal('12,'), isNull);
    });
  });
}
