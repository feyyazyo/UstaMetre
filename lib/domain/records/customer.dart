import '../../engine/calculator.dart';

/// Müşteri (kişi veya firma). Telefon, e-posta ve adres isteğe bağlıdır.
final class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.note = '',
  });

  final String id;

  /// Ad soyad veya firma adı.
  final String name;
  final String phone;
  final String email;
  final String address;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  void validate() {
    if (name.trim().isEmpty) {
      throw const CalculationException('Müşteri adı veya firma adı girin.');
    }
    final mail = email.trim();
    if (mail.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      throw const CalculationException('E-posta adresi geçerli görünmüyor.');
    }
  }

  /// Arama için ad, telefon, e-posta ve adreste geçer mi?
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      name,
      phone,
      email,
      address,
    ].any((f) => f.toLowerCase().contains(q));
  }

  Customer copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? note,
    DateTime? updatedAt,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    address: address ?? this.address,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Customer.fromJson(Map<String, Object?> json) => Customer(
    id: json['id']! as String,
    name: json['name']! as String,
    phone: (json['phone'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    address: (json['address'] as String?) ?? '',
    note: (json['note'] as String?) ?? '',
    createdAt: DateTime.parse(json['createdAt']! as String),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
  );
}
