import '../../engine/calculator.dart';

enum ProjectStatus {
  preparing('Hazırlanıyor'),
  quoted('Teklif verildi'),
  approved('Onaylandı'),
  inProgress('Devam ediyor'),
  completed('Tamamlandı'),
  cancelled('İptal edildi');

  const ProjectStatus(this.label);

  final String label;
}

/// İş / proje (ör. "Yılmaz mutfak tadilatı"). Bir projeye birden fazla hesap
/// bağlanabilir; müşteri isteğe bağlıdır.
final class Project {
  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.customerId,
    this.location = '',
    this.note = '',
    this.status = ProjectStatus.preparing,
  });

  final String id;
  final String name;
  final String? customerId;

  /// Adres veya proje konumu.
  final String location;
  final String note;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  void validate() {
    if (name.trim().isEmpty) {
      throw const CalculationException('Proje adı girin.');
    }
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [name, location, note].any((f) => f.toLowerCase().contains(q));
  }

  Project copyWith({
    String? name,
    String? customerId,
    bool clearCustomer = false,
    String? location,
    String? note,
    ProjectStatus? status,
    DateTime? updatedAt,
  }) => Project(
    id: id,
    name: name ?? this.name,
    customerId: clearCustomer ? null : (customerId ?? this.customerId),
    location: location ?? this.location,
    note: note ?? this.note,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'customerId': customerId,
    'location': location,
    'note': note,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Project.fromJson(Map<String, Object?> json) => Project(
    id: json['id']! as String,
    name: json['name']! as String,
    customerId: json['customerId'] as String?,
    location: (json['location'] as String?) ?? '',
    note: (json['note'] as String?) ?? '',
    status: ProjectStatus.values.byName(json['status']! as String),
    createdAt: DateTime.parse(json['createdAt']! as String),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
  );
}
