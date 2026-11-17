import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/number_format.dart';
import 'package:ustametre/engine/number_parser.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);

  group('formatDecimal', () {
    test('Türkçe ayırıcılar', () {
      expect(formatDecimal(d('1250.75')), '1.250,75');
      expect(formatDecimal(d('1234567')), '1.234.567');
      expect(formatDecimal(d('0.5')), '0,5');
      expect(formatDecimal(d('-1250.5')), '-1.250,5');
    });

    test('sondaki sıfırları atar', () {
      expect(formatDecimal(d('1.500')), '1,5');
      expect(formatDecimal(d('2.0000')), '2');
    });

    test('en fazla 4 haneye yarım yukarı yuvarlar', () {
      expect(formatDecimal(d('0.699678')), '0,6997');
      expect(formatDecimal(d('0.12345')), '0,1235');
    });

    test('formatQuantity yuvarlanmış değeri ≈ ile işaretler', () {
      expect(formatQuantity(d('1.584'), 'm²'), '1,584 m²');
      expect(formatQuantity(d('0.699678'), 'm²'), '≈0,6997 m²');
    });

    test('formatPercent', () {
      expect(formatPercent(d('10')), '%10');
      expect(formatPercent(d('7.5')), '%7,5');
    });
  });

  group('Türkçe sayı girişi ↔ biçim', () {
    test('ayrıştırılan değer aynı biçimde geri yazılır', () {
      for (final text in ['1.250,75', '0,5', '12', '1.000.000,25']) {
        expect(formatDecimal(parseDecimal(text)!), text);
      }
    });
  });
}
