import '../money.dart';
import '../pricing.dart';
import 'cost_item.dart';

/// Bir hesaplamaya eklenen ek maliyet kalemlerinin değişmez listesi.
///
/// Tüm işlemler yeni bir [CostSheet] döndürür; böylece geri alma, kayıt ve
/// test kolaylaşır.
final class CostSheet {
  const CostSheet([this.items = const []]);

  final List<CostItem> items;

  bool get isEmpty => items.isEmpty;

  CostItem? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Kalemi sona ekler. Aynı kimlik varsa [ArgumentError].
  CostSheet add(CostItem item) {
    if (byId(item.id) != null) {
      throw ArgumentError.value(item.id, 'id', 'Bu kimlikte kalem zaten var');
    }
    return CostSheet(List.unmodifiable([...items, item]));
  }

  /// Aynı kimlikli kalemi yenisiyle değiştirir (sıra korunur).
  CostSheet update(CostItem item) {
    final index = items.indexWhere((i) => i.id == item.id);
    if (index < 0) throw StateError('Kalem bulunamadı: ${item.id}');
    final next = [...items]..[index] = item;
    return CostSheet(List.unmodifiable(next));
  }

  CostSheet remove(String id) =>
      CostSheet(List.unmodifiable(items.where((i) => i.id != id)));

  /// Kalemin kopyasını hemen arkasına ekler. Kopya yeni kimlik alır ve
  /// adına " (kopya)" eklenir; fiyat ve kaynak aynen kopyalanır.
  CostSheet duplicate(String id, {required String newId}) {
    final index = items.indexWhere((i) => i.id == id);
    if (index < 0) throw StateError('Kalem bulunamadı: $id');
    final original = items[index];
    final copy = original.copyWith(id: newId, name: '${original.name} (kopya)');
    final next = [...items]..insert(index + 1, copy);
    return CostSheet(List.unmodifiable(next));
  }

  /// Tüm kalemleri doğrular (bkz. [CostItem.validate]).
  void validate() {
    for (final item in items) {
      item.validate();
    }
  }

  List<CostLine> toLines() => [for (final i in items) i.toLine()];

  Money get subtotal => items.fold(Money.zero, (sum, i) => sum + i.total);

  Money totalOf(CostKind kind) => items
      .where((i) => i.category == kind)
      .fold(Money.zero, (sum, i) => sum + i.total);

  List<Map<String, Object?>> toJson() => [for (final i in items) i.toJson()];

  factory CostSheet.fromJson(List<Object?> json) => CostSheet(
    List.unmodifiable([
      for (final e in json)
        CostItem.fromJson((e! as Map).cast<String, Object?>()),
    ]),
  );
}
