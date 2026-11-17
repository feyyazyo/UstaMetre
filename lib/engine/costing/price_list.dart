import 'package:decimal/decimal.dart';

import '../calculator.dart';
import '../money.dart';
import '../pricing.dart';
import 'cost_item.dart';

/// Fiyat geçmişindeki tek kayıt: belirli bir tarihten itibaren geçerli
/// fiyat ve birim.
final class PricePoint {
  const PricePoint({
    required this.price,
    required this.unit,
    required this.effectiveFrom,
  });

  final Money price;
  final CostUnit unit;
  final DateTime effectiveFrom;

  Map<String, Object?> toJson() => {
    'priceKurus': price.kurus.toString(),
    'unit': unit.name,
    'effectiveFrom': effectiveFrom.toIso8601String(),
  };

  factory PricePoint.fromJson(Map<String, Object?> json) => PricePoint(
    price: Money.fromKurusBig(BigInt.parse(json['priceKurus']! as String)),
    unit: CostUnit.byName(json['unit']! as String),
    effectiveFrom: DateTime.parse(json['effectiveFrom']! as String),
  );
}

/// Fiyat listesi kaydı. Fiyat ve birim değişiklikleri üzerine yazılmaz,
/// [history] listesine eklenir.
final class PriceListItem {
  PriceListItem._({
    required this.id,
    required this.name,
    required this.category,
    required this.history,
    required this.description,
    required this.userDefined,
  });

  factory PriceListItem.create({
    required String id,
    required String name,
    required CostKind category,
    required CostUnit unit,
    required Money price,
    required DateTime at,
    String description = '',
    bool userDefined = true,
  }) {
    _validate(name, price);
    return PriceListItem._(
      id: id,
      name: name.trim(),
      category: category,
      description: description,
      userDefined: userDefined,
      history: List.unmodifiable([
        PricePoint(price: price, unit: unit, effectiveFrom: at),
      ]),
    );
  }

  final String id;
  final String name;
  final CostKind category;
  final String description;

  /// Kullanıcının kendi oluşturduğu kalem mi (ör. hesaplamadan "fiyat
  /// listesine kaydet" ile eklenen).
  final bool userDefined;

  /// Eskiden yeniye sıralı, boş olmayan fiyat/birim geçmişi.
  final List<PricePoint> history;

  PricePoint get current => history.last;
  Money get price => current.price;
  CostUnit get unit => current.unit;

  /// [at] anında geçerli fiyat kaydı; o tarihte kayıt yoksa `null`.
  PricePoint? pointAt(DateTime at) {
    PricePoint? found;
    for (final p in history) {
      if (!p.effectiveFrom.isAfter(at)) found = p;
    }
    return found;
  }

  /// Yeni fiyat (ve isteğe bağlı yeni birim) kaydı ekler. Fiyat ve birim
  /// aynıysa değişiklik yapılmaz. Geçmişe dönük kayıt eklenemez.
  PriceListItem withPrice(Money price, {required DateTime at, CostUnit? unit}) {
    _validate(name, price);
    final newUnit = unit ?? this.unit;
    if (price == this.price && newUnit == this.unit) return this;
    if (at.isBefore(current.effectiveFrom)) {
      throw const CalculationException(
        'Yeni fiyat, son fiyatın tarihinden önce olamaz.',
      );
    }
    return _copy(
      history: List.unmodifiable([
        ...history,
        PricePoint(price: price, unit: newUnit, effectiveFrom: at),
      ]),
    );
  }

  /// Ad, açıklama veya kategori değiştirir; fiyat geçmişine dokunmaz.
  PriceListItem rename({
    String? name,
    String? description,
    CostKind? category,
  }) {
    if (name != null && name.trim().isEmpty) {
      throw const CalculationException('Kalem adı boş olamaz.');
    }
    return _copy(
      name: name?.trim(),
      description: description,
      category: category,
    );
  }

  /// Hesaplamaya eklenecek kalem üretir. Fiyat **kopyalanır**; liste
  /// sonradan değişse bile bu kalemin tutarı değişmez.
  CostItem toCostItem({required String id, Decimal? quantity}) => CostItem(
    id: id,
    name: name,
    description: description,
    category: category,
    quantity: quantity ?? Decimal.one,
    unit: unit,
    unitPrice: price,
    source: PriceSource(
      priceListItemId: this.id,
      effectiveFrom: current.effectiveFrom,
    ),
  );

  PriceListItem _copy({
    String? name,
    String? description,
    CostKind? category,
    List<PricePoint>? history,
  }) => PriceListItem._(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    description: description ?? this.description,
    userDefined: userDefined,
    history: history ?? this.history,
  );

  static void _validate(String name, Money price) {
    if (name.trim().isEmpty) {
      throw const CalculationException('Kalem adı boş olamaz.');
    }
    if (price.isNegative) {
      throw const CalculationException('Fiyat negatif olamaz.');
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'description': description,
    'userDefined': userDefined,
    'history': [for (final p in history) p.toJson()],
  };

  factory PriceListItem.fromJson(Map<String, Object?> json) {
    final history = [
      for (final p in json['history']! as List)
        PricePoint.fromJson((p! as Map).cast<String, Object?>()),
    ];
    if (history.isEmpty) {
      throw const FormatException('Fiyat geçmişi boş olamaz');
    }
    return PriceListItem._(
      id: json['id']! as String,
      name: json['name']! as String,
      category: CostKind.values.byName(json['category']! as String),
      description: (json['description'] as String?) ?? '',
      userDefined: (json['userDefined'] as bool?) ?? true,
      history: List.unmodifiable(history),
    );
  }
}

/// Kullanıcının fiyat listesi (malzeme, işçilik, aksesuar, nakliye, diğer).
/// Değişmezdir; her işlem yeni liste döndürür.
final class PriceList {
  const PriceList([this.items = const []]);

  final List<PriceListItem> items;

  static const int schemaVersion = 1;

  PriceListItem? byId(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  List<PriceListItem> byCategory(CostKind kind) =>
      items.where((i) => i.category == kind).toList();

  PriceList add(PriceListItem item) {
    if (byId(item.id) != null) {
      throw ArgumentError.value(item.id, 'id', 'Bu kimlikte kayıt zaten var');
    }
    return PriceList(List.unmodifiable([...items, item]));
  }

  PriceList replace(PriceListItem item) {
    final index = items.indexWhere((i) => i.id == item.id);
    if (index < 0) throw StateError('Kayıt bulunamadı: ${item.id}');
    return PriceList(List.unmodifiable([...items]..[index] = item));
  }

  PriceList updatePrice(
    String id,
    Money price, {
    required DateTime at,
    CostUnit? unit,
  }) {
    final item = byId(id);
    if (item == null) throw StateError('Kayıt bulunamadı: $id');
    return replace(item.withPrice(price, at: at, unit: unit));
  }

  PriceList remove(String id) =>
      PriceList(List.unmodifiable(items.where((i) => i.id != id)));

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'items': [for (final i in items) i.toJson()],
  };

  factory PriceList.fromJson(Map<String, Object?> json) => PriceList(
    List.unmodifiable([
      for (final i in json['items']! as List)
        PriceListItem.fromJson((i! as Map).cast<String, Object?>()),
    ]),
  );
}
