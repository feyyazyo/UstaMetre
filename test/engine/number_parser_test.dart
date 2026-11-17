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
