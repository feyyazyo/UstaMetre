import '../../engine/calculation_result.dart';
import '../../engine/calculator.dart';
import '../../engine/money.dart';

/// Hesabın hangi ekranda yapıldığı (yeniden düzenlemek için gerekir).
enum CalcKind {
  quick('Hızlı hesap'),
  marbleProject('Mermer tezgâh projesi'),
  pvcProject('PVC doğrama projesi');

  const CalcKind(this.label);

  final String label;
}

/// Kaydedilmiş bir hesabın tek bir sürümü.
///
/// Girdiler (ölçüler, birimler, fire, birim fiyatlar, ek kalemler, indirim,
/// KDV) ve sonuç (satırlar, toplamlar, açıklama adımları) kayıt anındaki
/// değerleriyle saklanır. Fiyat listesi veya hesap kuralları sonradan
/// değişse de bu sürüm değişmez.
final class CalcRevision {
  const CalcRevision({
    required this.number,
    required this.savedAt,
    required this.categoryId,
    required this.kind,
    required this.modeLabel,
    required this.inputs,
    required this.result,
    this.note = '',
  });

  /// Kayıt biçiminin sürümü. Alan eklenip çıkarıldığında artırılır ve
  /// [migrateRevisionJson] içinde eski biçimden dönüşüm yazılır.
  static const int schemaVersion = 1;

  /// 1'den başlayan sürüm numarası.
  final int number;
  final DateTime savedAt;
  final String categoryId;
  final CalcKind kind;

  /// Hesap türü (ör. "Alan (m²)", "Tezgâh projesi").
  final String modeLabel;

  /// Ekrana özgü girdi kopyası (yeniden düzenleme için).
  final Map<String, Object?> inputs;
  final CalculationResult result;
  final String note;

  Money? get grandTotal => result.price?.grandTotal;

  CalcRevision copyWith({int? number, DateTime? savedAt, String? note}) =>
      CalcRevision(
        number: number ?? this.number,
        savedAt: savedAt ?? this.savedAt,
        categoryId: categoryId,
        kind: kind,
        modeLabel: modeLabel,
        inputs: inputs,
        result: result,
        note: note ?? this.note,
      );

  Map<String, Object?> toJson() => {
    'schema': schemaVersion,
    'number': number,
    'savedAt': savedAt.toIso8601String(),
    'categoryId': categoryId,
    'kind': kind.name,
    'modeLabel': modeLabel,
    'note': note,
    'inputs': inputs,
    'result': result.toJson(),
  };

  factory CalcRevision.fromJson(Map<String, Object?> raw) {
    final json = migrateRevisionJson(raw);
    return CalcRevision(
      number: json['number']! as int,
      savedAt: DateTime.parse(json['savedAt']! as String),
      categoryId: json['categoryId']! as String,
      kind: CalcKind.values.byName(json['kind']! as String),
      modeLabel: (json['modeLabel'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
      inputs: ((json['inputs'] as Map?) ?? const {}).cast<String, Object?>(),
      result: CalculationResult.fromJson(
        (json['result']! as Map).cast<String, Object?>(),
      ),
    );
  }
}

/// Eski biçimdeki kaydı güncel biçime adım adım taşır. Bilinmeyen (daha yeni)
/// bir sürüm görülürse [FormatException] fırlar; kayıt silinmez, "okunamayan
/// kayıt" olarak korunur.
Map<String, Object?> migrateRevisionJson(Map<String, Object?> json) {
  var version = (json['schema'] as int?) ?? 0;
  if (version > CalcRevision.schemaVersion) {
    throw FormatException(
      'Kayıt daha yeni bir uygulama sürümüyle oluşturulmuş (biçim $version).',
    );
  }
  var current = Map<String, Object?>.of(json);
  // Biçim 0 (sürüm alanı olmayan erken kayıtlar): not ve tür etiketi yoktu.
  if (version == 0) {
    current = {
      ...current,
      'modeLabel': current['modeLabel'] ?? '',
      'note': current['note'] ?? '',
      'schema': 1,
    };
    version = 1;
  }
  // Gelecek biçimler buraya eklenir: if (version == 1) {...; version = 2;}
  return current;
}

/// Kaydedilmiş hesap: güncel sürüm + kayıt bilgileri. Önceki sürümler ayrıca
/// saklanır (bkz. depo `revisions`).
final class SavedCalculation {
  const SavedCalculation({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.current,
    this.customerId,
    this.projectId,
  });

  final String id;
  final String name;
  final String? customerId;
  final String? projectId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CalcRevision current;

  String get categoryId => current.categoryId;
  CalcKind get kind => current.kind;
  int get revisionNumber => current.number;
  Money? get grandTotal => current.grandTotal;

  void validate() {
    if (name.trim().isEmpty) {
      throw const CalculationException('Hesap adı girin.');
    }
  }

  SavedCalculation copyWith({
    String? name,
    String? customerId,
    String? projectId,
    bool clearCustomer = false,
    bool clearProject = false,
    DateTime? updatedAt,
    CalcRevision? current,
  }) => SavedCalculation(
    id: id,
    name: name ?? this.name,
    customerId: clearCustomer ? null : (customerId ?? this.customerId),
    projectId: clearProject ? null : (projectId ?? this.projectId),
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    current: current ?? this.current,
  );
}
