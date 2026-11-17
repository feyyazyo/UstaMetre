import 'package:decimal/decimal.dart';

/// Kullanıcının girdiği sayısal metni kesin [Decimal] değere çevirir.
///
/// Türkçe yazım alışkanlıklarını destekler:
/// * `12,5`      → 12.5
/// * `1.250,75`  → 1250.75
/// * `1250.75`   → 1250.75 (tek nokta ve ardından 1-2 hane ise ondalık kabul edilir)
/// * `1.250`     → 1250 (nokta ardından tam 3 hane: binlik ayırıcı)
///
/// Geçersiz girişte `null` döner; asla `double` kullanılmaz.
Decimal? parseDecimal(String input) {
  var text = input.trim().replaceAll(' ', '').replaceAll(' ', '');
  if (text.isEmpty) return null;

  final hasComma = text.contains(',');
  final dotCount = '.'.allMatches(text).length;

  if (hasComma) {
    // Virgül ondalık ayırıcıdır; noktalar binlik ayırıcıdır.
    if (','.allMatches(text).length > 1) return null;
    text = text.replaceAll('.', '').replaceAll(',', '.');
  } else if (dotCount > 1) {
    // Birden fazla nokta: hepsi binlik ayırıcı.
    text = text.replaceAll('.', '');
  } else if (dotCount == 1) {
    final decimals = text.length - text.indexOf('.') - 1;
    if (decimals == 3) {
      // "1.250" Türkçede bin iki yüz elli demektir.
      text = text.replaceAll('.', '');
    }
  }

  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(text)) return null;
  return Decimal.tryParse(text);
}
