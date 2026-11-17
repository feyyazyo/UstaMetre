import 'package:decimal/decimal.dart';

import 'pricing.dart';

/// Sonuçta gösterilen bir ölçü değeri (ör. "Fireli alan: 1,584 m²").
final class ResultFigure {
  const ResultFigure({
    required this.label,
    required this.value,
    required this.unit,
    this.highlighted = false,
  });

  final String label;
  final Decimal value;
  final String unit;

  /// Sonucun ana değeri mi (arayüzde vurgulanır).
  final bool highlighted;

  Map<String, Object?> toJson() => {
    'label': label,
    'value': value.toString(),
    'unit': unit,
    'highlighted': highlighted,
  };
}

/// Bir hesaplamanın tam sonucu: ölçüler, isteğe bağlı fiyat özeti ve
/// hesabın adım adım Türkçe açıklaması.
final class CalculationResult {
  const CalculationResult({
    required this.figures,
    required this.steps,
    this.price,
    this.warnings = const [],
  });

  final List<ResultFigure> figures;

  /// Birim fiyat girilmediyse `null`.
  final PriceSummary? price;

  /// "Nasıl hesaplandı?" bölümünde gösterilen adımlar.
  final List<String> steps;

  /// Uyarılar (ör. doğrulanmamış profil formülü). Arayüzde belirgin
  /// gösterilir ve teklife aktarılırken korunmalıdır.
  final List<String> warnings;

  /// Sonucun tamamını (ölçüler, satırlar, toplamlar, adımlar) düz veri olarak
  /// verir. İleride PDF teklif ve kayıt sistemine bu yapı aktarılacaktır.
  Map<String, Object?> toJson() => {
    'figures': [for (final f in figures) f.toJson()],
    'price': price?.toJson(),
    'steps': steps,
    'warnings': warnings,
  };
}
