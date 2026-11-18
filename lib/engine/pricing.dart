import 'package:decimal/decimal.dart';

import 'calculator.dart';
import 'money.dart';
import 'number_format.dart';

/// Maliyet kaleminin kategorisi.
enum CostKind {
  material('Malzeme'),
  labor('İşçilik'),
  accessory('Aksesuar'),
  shipping('Nakliye'),
  other('Diğer');

  const CostKind(this.label);

  final String label;
}

/// Teklif/hesap satırı: miktar × birim fiyat = tutar (kuruşa yuvarlanır).
final class CostLine {
  CostLine({
    required this.label,
    required this.kind,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.description = '',
  }) : amount = unitPrice.multiply(quantity);

  CostLine._restored({
    required this.label,
    required this.kind,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.description,
    required this.amount,
  });

  /// Kaydedilmiş satırı **olduğu gibi** geri yükler: tutar yeniden
  /// hesaplanmaz, kayıt anındaki değer korunur.
  factory CostLine.fromJson(Map<String, Object?> json) => CostLine._restored(
    label: json['label']! as String,
    description: (json['description'] as String?) ?? '',
    kind: CostKind.values.byName(json['kind']! as String),
    quantity: Decimal.parse(json['quantity']! as String),
    unit: json['unit']! as String,
    unitPrice: _kurus(json['unitPriceKurus']),
    amount: _kurus(json['amountKurus']),
  );

  final String label;
  final CostKind kind;
  final Decimal quantity;
  final String unit;
  final Money unitPrice;
  final String description;

  /// `unitPrice × quantity`, kuruşa yarım yukarı yuvarlanmış.
  final Money amount;

  Map<String, Object?> toJson() => {
    'label': label,
    'description': description,
    'kind': kind.name,
    'quantity': quantity.toString(),
    'unit': unit,
    'unitPriceKurus': unitPrice.kurus.toString(),
    'amountKurus': amount.kurus.toString(),
  };
}

/// Ara toplama uygulanan indirim.
sealed class Discount {
  const Discount();

  /// [subtotal] üzerinden indirim tutarı (kuruşa yuvarlanmış).
  Money amountFor(Money subtotal);

  String get description;

  Map<String, Object?> toJson();

  static Discount? fromJson(Object? json) {
    if (json is! Map) return null;
    return switch (json['type']) {
      'percent' => PercentDiscount(Decimal.parse(json['value']! as String)),
      'amount' => AmountDiscount(_kurus(json['valueKurus'])),
      _ => null,
    };
  }
}

Money _kurus(Object? value) =>
    Money.fromKurusBig(BigInt.parse(value! as String));

/// Yüzde indirim (ör. %5).
final class PercentDiscount extends Discount {
  PercentDiscount(this.percent) {
    if (percent < Decimal.zero || percent > Decimal.fromInt(100)) {
      throw const CalculationException(
        'İndirim oranı %0 ile %100 arasında olmalıdır.',
      );
    }
  }

  final Decimal percent;

  @override
  Money amountFor(Money subtotal) => subtotal.percent(percent);

  @override
  String get description => formatPercent(percent);

  @override
  Map<String, Object?> toJson() => {
    'type': 'percent',
    'value': percent.toString(),
  };
}

/// Sabit tutarlı indirim (ör. ₺500).
final class AmountDiscount extends Discount {
  AmountDiscount(this.amount) {
    if (amount.isNegative) {
      throw const CalculationException('İndirim tutarı negatif olamaz.');
    }
  }

  final Money amount;

  @override
  Money amountFor(Money subtotal) {
    if (amount > subtotal) {
      throw const CalculationException(
        'İndirim tutarı ara toplamdan büyük olamaz.',
      );
    }
    return amount;
  }

  @override
  String get description => amount.format();

  @override
  Map<String, Object?> toJson() => {
    'type': 'amount',
    'valueKurus': amount.kurus.toString(),
  };
}

/// Fiyatların arayüzde KDV hariç mi dahil mi gösterileceği.
enum VatDisplayMode {
  excluded('KDV hariç'),
  included('KDV dahil');

  const VatDisplayMode(this.label);

  final String label;
}

/// Satırların ara toplamı, indirim, KDV ve genel toplam.
///
/// Sıra: ara toplam → indirim → KDV matrahı → KDV → genel toplam.
/// Her adım kuruşa yuvarlanır; böylece
/// `araToplam − indirim + kdv == genelToplam` her zaman kuruşu kuruşuna tutar.
final class PriceSummary {
  PriceSummary._({
    required this.lines,
    required this.vatPercent,
    required this.subtotal,
    required this.discountRule,
    required this.discount,
    required this.taxBase,
    required this.vat,
    required this.grandTotal,
  });

  /// Kaydedilmiş özeti **olduğu gibi** geri yükler. Hiçbir tutar yeniden
  /// hesaplanmaz; böylece hesaplama kuralları veya fiyat listesi sonradan
  /// değişse de eski kayıt aynı kalır.
  factory PriceSummary.fromJson(Map<String, Object?> json) => PriceSummary._(
    lines: List.unmodifiable([
      for (final l in json['lines']! as List)
        CostLine.fromJson((l! as Map).cast<String, Object?>()),
    ]),
    vatPercent: Decimal.parse(json['vatPercent']! as String),
    subtotal: _kurus(json['subtotalKurus']),
    discountRule: Discount.fromJson(json['discountRule']),
    discount: _kurus(json['discountKurus']),
    taxBase: _kurus(json['taxBaseKurus']),
    vat: _kurus(json['vatKurus']),
    grandTotal: _kurus(json['grandTotalKurus']),
  );

  factory PriceSummary.fromLines(
    List<CostLine> lines, {
    Decimal? vatPercent,
    Discount? discount,
  }) {
    final rate = vatPercent ?? Decimal.zero;
    if (rate < Decimal.zero || rate > Decimal.fromInt(100)) {
      throw const CalculationException(
        'KDV oranı %0 ile %100 arasında olmalıdır.',
      );
    }
    final subtotal = lines.fold(Money.zero, (sum, l) => sum + l.amount);
    final discountAmount = discount?.amountFor(subtotal) ?? Money.zero;
    final taxBase = subtotal - discountAmount;
    final vat = taxBase.percent(rate);
    return PriceSummary._(
      lines: List.unmodifiable(lines),
      vatPercent: rate,
      subtotal: subtotal,
      discountRule: discount,
      discount: discountAmount,
      taxBase: taxBase,
      vat: vat,
      grandTotal: taxBase + vat,
    );
  }

  final List<CostLine> lines;
  final Decimal vatPercent;

  /// Ara toplam (indirim ve KDV hariç).
  final Money subtotal;

  /// Uygulanan indirim kuralı (yoksa `null`).
  final Discount? discountRule;

  /// İndirim tutarı.
  final Money discount;

  /// KDV matrahı: ara toplam − indirim.
  final Money taxBase;
  final Money vat;

  /// Genel toplam (KDV dahil).
  final Money grandTotal;

  bool get hasDiscount => discount > Money.zero;

  /// Belirli bir kategorideki satırların toplamı (ör. tüm işçilik).
  Money totalOf(CostKind kind) => lines
      .where((l) => l.kind == kind)
      .fold(Money.zero, (sum, l) => sum + l.amount);

  /// Satırda bulunan kategoriler (tanım sırasıyla).
  List<CostKind> get kinds => [
    for (final k in CostKind.values)
      if (lines.any((l) => l.kind == k)) k,
  ];

  /// Satır tutarını gösterim moduna göre verir. KDV dahil modda satır
  /// tutarına KDV eklenip kuruşa yuvarlanır (indirim öncesi). Bu yüzden KDV
  /// dahil satırların toplamı genel toplamdan kuruş düzeyinde farklı
  /// olabilir; bağlayıcı olan [grandTotal]'dır.
  Money displayAmount(Money amount, VatDisplayMode mode) =>
      mode == VatDisplayMode.included
      ? amount + amount.percent(vatPercent)
      : amount;

  Map<String, Object?> toJson() => {
    'lines': [for (final l in lines) l.toJson()],
    'vatPercent': vatPercent.toString(),
    'subtotalKurus': subtotal.kurus.toString(),
    'discount': discountRule?.description,
    'discountRule': discountRule?.toJson(),
    'kindTotals': {for (final k in kinds) k.name: totalOf(k).kurus.toString()},
    'discountKurus': discount.kurus.toString(),
    'taxBaseKurus': taxBase.kurus.toString(),
    'vatKurus': vat.kurus.toString(),
    'grandTotalKurus': grandTotal.kurus.toString(),
  };
}
