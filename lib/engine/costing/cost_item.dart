import 'package:decimal/decimal.dart';

import '../calculator.dart';
import '../money.dart';
import '../pricing.dart';

/// Maliyet kalemi birimleri.
enum CostUnit {
  piece('adet', 'Adet'),
  squareMeter('m²', 'Metrekare'),
  linearMeter('mtül', 'Metre tül'),
  meter('m', 'Metre'),
  kilogram('kg', 'Kilogram'),
  hour('saat', 'Saat'),
  service('hizmet', 'Hizmet (götürü)');

  const CostUnit(this.symbol, this.label);

  final String symbol;
  final String label;

  static CostUnit byName(String name) =>
      CostUnit.values.firstWhere((u) => u.name == name);
}

/// Kalemin fiyatının fiyat listesinden hangi kayıttan kopyalandığı.
///
/// Kalem fiyatı **kopya** olarak tutulur; fiyat listesi sonradan değişse de
/// bu kalemin tutarı değişmez. Bu bilgi yalnızca izlenebilirlik içindir.
final class PriceSource {
  const PriceSource({
    required this.priceListItemId,
    required this.effectiveFrom,
  });

  final String priceListItemId;
  final DateTime effectiveFrom;

  Map<String, Object?> toJson() => {
    'priceListItemId': priceListItemId,
    'effectiveFrom': effectiveFrom.toIso8601String(),
  };

  factory PriceSource.fromJson(Map<String, Object?> json) => PriceSource(
    priceListItemId: json['priceListItemId']! as String,
    effectiveFrom: DateTime.parse(json['effectiveFrom']! as String),
  );

  @override
  bool operator ==(Object other) =>
      other is PriceSource &&
      other.priceListItemId == priceListItemId &&
      other.effectiveFrom == effectiveFrom;

  @override
  int get hashCode => Object.hash(priceListItemId, effectiveFrom);
}

/// Bütün meslek modüllerinin kullandığı ortak maliyet kalemi
/// (ör. "Evye montajı · İşçilik · 1 adet × ₺750").
final class CostItem {
  const CostItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.description = '',
    this.source,
  });

  final String id;
  final String name;
  final String description;
  final CostKind category;
  final Decimal quantity;
  final CostUnit unit;

  /// Birim fiyat (KDV hariç).
  final Money unitPrice;

  /// Fiyat listesinden geldiyse kaynağı.
  final PriceSource? source;

  /// Miktar × birim fiyat, kuruşa yarım yukarı yuvarlanmış.
  Money get total => unitPrice.multiply(quantity);

  /// Kalemin hesaplanabilir olduğunu doğrular; değilse Türkçe açıklamalı
  /// [CalculationException] fırlatır.
  void validate() {
    if (name.trim().isEmpty) {
      throw const CalculationException('Kalem adı boş olamaz.');
    }
    if (quantity <= Decimal.zero) {
      throw CalculationException('"$name" miktarı sıfırdan büyük olmalıdır.');
    }
    if (unitPrice.isNegative) {
      throw CalculationException('"$name" birim fiyatı negatif olamaz.');
    }
  }

  CostLine toLine() => CostLine(
    label: name,
    description: description,
    kind: category,
    quantity: quantity,
    unit: unit.symbol,
    unitPrice: unitPrice,
  );

  CostItem copyWith({
    String? id,
    String? name,
    String? description,
    CostKind? category,
    Decimal? quantity,
    CostUnit? unit,
    Money? unitPrice,
    PriceSource? source,
    bool clearSource = false,
  }) => CostItem(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    category: category ?? this.category,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    unitPrice: unitPrice ?? this.unitPrice,
    source: clearSource ? null : (source ?? this.source),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category.name,
    'quantity': quantity.toString(),
    'unit': unit.name,
    'unitPriceKurus': unitPrice.kurus.toString(),
    if (source != null) 'source': source!.toJson(),
  };

  factory CostItem.fromJson(Map<String, Object?> json) => CostItem(
    id: json['id']! as String,
    name: json['name']! as String,
    description: (json['description'] as String?) ?? '',
    category: CostKind.values.byName(json['category']! as String),
    quantity: Decimal.parse(json['quantity']! as String),
    unit: CostUnit.byName(json['unit']! as String),
    unitPrice: Money.fromKurusBig(
      BigInt.parse(json['unitPriceKurus']! as String),
    ),
    source: json['source'] == null
        ? null
        : PriceSource.fromJson(
            (json['source']! as Map).cast<String, Object?>(),
          ),
  );
}

/// Bir mesleğe özgü hazır kalem şablonu (ör. mermer "Evye montajı").
/// Kullanıcı eklerken miktar ve fiyatı girer.
final class CostTemplate {
  const CostTemplate({
    required this.name,
    required this.category,
    required this.unit,
    this.description = '',
  });

  final String name;
  final CostKind category;
  final CostUnit unit;
  final String description;

  CostItem toItem({required String id, Decimal? quantity, Money? unitPrice}) =>
      CostItem(
        id: id,
        name: name,
        description: description,
        category: category,
        quantity: quantity ?? Decimal.one,
        unit: unit,
        unitPrice: unitPrice ?? Money.zero,
      );
}
