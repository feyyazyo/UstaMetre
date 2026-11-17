import 'package:decimal/decimal.dart';

import 'calculator.dart';
import 'money.dart';

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
}

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
  String get description => '%$percent';
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
  }) : taxBase = subtotal - discount,
       vat = (subtotal - discount).percent(vatPercent),
       grandTotal =
           (subtotal - discount) + (subtotal - discount).percent(vatPercent);

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
    return PriceSummary._(
      lines: List.unmodifiable(lines),
      vatPercent: rate,
      subtotal: subtotal,
      discountRule: discount,
      discount: discount?.amountFor(subtotal) ?? Money.zero,
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
    'discountKurus': discount.kurus.toString(),
    'taxBaseKurus': taxBase.kurus.toString(),
    'vatKurus': vat.kurus.toString(),
    'grandTotalKurus': grandTotal.kurus.toString(),
  };
}
