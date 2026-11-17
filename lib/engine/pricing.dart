import 'package:decimal/decimal.dart';

import 'money.dart';

/// Maliyet kaleminin türü.
enum CostKind {
  material('Malzeme'),
  labor('İşçilik'),
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
  }) : amount = unitPrice.multiply(quantity);

  final String label;
  final CostKind kind;
  final Decimal quantity;
  final String unit;
  final Money unitPrice;

  /// `unitPrice × quantity`, kuruşa yarım yukarı yuvarlanmış.
  final Money amount;
}

/// Satırların ara toplamı, KDV ve genel toplam.
///
/// KDV, kuruşa yuvarlanmış ara toplam üzerinden hesaplanır ve kendisi de
/// kuruşa yuvarlanır. Böylece `araToplam + kdv == genelToplam` her zaman
/// kuruşu kuruşuna tutar.
final class PriceSummary {
  PriceSummary._({
    required this.lines,
    required this.vatPercent,
    required this.subtotal,
    required this.vat,
  }) : grandTotal = subtotal + vat;

  factory PriceSummary.fromLines(List<CostLine> lines, {Decimal? vatPercent}) {
    final rate = vatPercent ?? Decimal.zero;
    final subtotal = lines.fold(Money.zero, (sum, l) => sum + l.amount);
    return PriceSummary._(
      lines: List.unmodifiable(lines),
      vatPercent: rate,
      subtotal: subtotal,
      vat: subtotal.percent(rate),
    );
  }

  final List<CostLine> lines;
  final Decimal vatPercent;

  /// Ara toplam (KDV hariç).
  final Money subtotal;
  final Money vat;

  /// Genel toplam (KDV dahil).
  final Money grandTotal;

  /// Belirli bir türdeki satırların toplamı (ör. tüm işçilik).
  Money totalOf(CostKind kind) => lines
      .where((l) => l.kind == kind)
      .fold(Money.zero, (sum, l) => sum + l.amount);
}
