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

  factory ResultFigure.fromJson(Map<String, Object?> json) => ResultFigure(
    label: json['label']! as String,
    value: Decimal.parse(json['value']! as String),
    unit: json['unit']! as String,
    highlighted: (json['highlighted'] as bool?) ?? false,
  );

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
  /// Kaydedilmiş sonucu tutarları yeniden hesaplamadan geri yükler.
  factory CalculationResult.fromJson(Map<String, Object?> json) =>
      CalculationResult(
        figures: [
          for (final f in json['figures']! as List)
            ResultFigure.fromJson((f! as Map).cast<String, Object?>()),
        ],
        price: json['price'] == null
            ? null
            : PriceSummary.fromJson(
                (json['price']! as Map).cast<String, Object?>(),
              ),
        steps: [for (final s in json['steps']! as List) s! as String],
        warnings: [
          for (final w in (json['warnings'] as List?) ?? const []) w! as String,
        ],
      );

  Map<String, Object?> toJson() => {
    'figures': [for (final f in figures) f.toJson()],
    'price': price?.toJson(),
    'steps': steps,
    'warnings': warnings,
  };
}
