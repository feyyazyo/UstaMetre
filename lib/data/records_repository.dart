import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/records/customer.dart';
import '../domain/records/project.dart';
import '../domain/records/saved_calculation.dart';
import '../engine/calculator.dart';
import '../engine/ids.dart';
import 'db/app_database.dart';

/// Okunamayan (bozuk veya daha yeni sürüme ait) kayıt. Silinmez; kullanıcıya
/// bildirilir ve yedeğe ham hâliyle eklenir.
final class CorruptRecord {
  const CorruptRecord({
    required this.table,
    required this.id,
    required this.error,
  });

  final String table;
  final String id;
  final String error;
}

/// Depodaki tüm kayıtların anlık görüntüsü.
final class RecordsSnapshot {
  const RecordsSnapshot({
    this.customers = const [],
    this.projects = const [],
    this.calculations = const [],
    this.corrupt = const [],
  });

  final List<Customer> customers;
  final List<Project> projects;
  final List<SavedCalculation> calculations;
  final List<CorruptRecord> corrupt;
}

/// Müşteri, proje ve kayıtlı hesapların yerel (SQLite) deposu. Arayüzden
/// bağımsızdır; tüm veritabanı işlemleri buradadır.
class RecordsRepository {
  RecordsRepository(this._db, {IdGenerator? ids, DateTime Function()? clock})
    : ids = ids ?? TimestampIdGenerator(),
      _clock = clock ?? DateTime.now;

  final Database _db;
  final IdGenerator ids;
  final DateTime Function() _clock;

  static const backupFormat = 'ustametre-backup';
  static const backupVersion = 1;

  /// Dosyadan (veya [inMemoryDatabasePath]) açar; şema gerekirse yükseltilir.
  static Future<RecordsRepository> open(
    DatabaseFactory factory,
    String path, {
    IdGenerator? ids,
    DateTime Function()? clock,
  }) async => RecordsRepository(
    await AppDatabase.open(factory, path),
    ids: ids,
    clock: clock,
  );

  Future<void> close() => _db.close();

  DateTime get _now => _clock();

  // ---------------------------------------------------------------- okuma

  Future<RecordsSnapshot> loadAll() async {
    final corrupt = <CorruptRecord>[];

    final customers = <Customer>[];
    for (final row in await _db.query(
      'customers',
      orderBy: 'name COLLATE NOCASE',
    )) {
      try {
        customers.add(_customerFromRow(row));
      } on Object catch (e) {
        corrupt.add(
          CorruptRecord(table: 'customers', id: '${row['id']}', error: '$e'),
        );
      }
    }

    final projects = <Project>[];
    for (final row in await _db.query('projects', orderBy: 'created_at DESC')) {
      try {
        projects.add(_projectFromRow(row));
      } on Object catch (e) {
        corrupt.add(
          CorruptRecord(table: 'projects', id: '${row['id']}', error: '$e'),
        );
      }
    }

    final calculations = <SavedCalculation>[];
    final rows = await _db.rawQuery('''
      SELECT c.*, r.payload AS payload
      FROM calculations c
      LEFT JOIN calculation_revisions r
        ON r.calculation_id = c.id AND r.revision = c.current_revision
      ORDER BY c.updated_at DESC''');
    for (final row in rows) {
      try {
        calculations.add(_calculationFromRow(row));
      } on Object catch (e) {
        corrupt.add(
          CorruptRecord(table: 'calculations', id: '${row['id']}', error: '$e'),
        );
      }
    }

    return RecordsSnapshot(
      customers: List.unmodifiable(customers),
      projects: List.unmodifiable(projects),
      calculations: List.unmodifiable(calculations),
      corrupt: List.unmodifiable(corrupt),
    );
  }

  /// Hesabın tüm sürümleri (eskiden yeniye). Okunamayan sürümler atlanır.
  Future<List<CalcRevision>> revisions(String calculationId) async {
    final rows = await _db.query(
      'calculation_revisions',
      where: 'calculation_id = ?',
      whereArgs: [calculationId],
      orderBy: 'revision ASC',
    );
    final result = <CalcRevision>[];
    for (final row in rows) {
      try {
        result.add(_revisionFromPayload(row['payload']! as String));
      } on Object {
        // Bozuk sürüm silinmez; listede yalnızca gösterilmez.
      }
    }
    return result;
  }

  // ------------------------------------------------------------ müşteriler

  Future<Customer> saveCustomer({
    String? id,
    required String name,
    String phone = '',
    String email = '',
    String address = '',
    String note = '',
  }) async {
    final now = _now;
    final existing = id == null ? null : await _customerById(id);
    final customer = Customer(
      id: existing?.id ?? ids.next(),
      name: name.trim(),
      phone: phone.trim(),
      email: email.trim(),
      address: address.trim(),
      note: note.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    customer.validate();
    await _db.insert(
      'customers',
      _customerToRow(customer),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return customer;
  }

  /// Müşteriyi siler. Bağlı projeler ve hesaplar **silinmez**; yalnızca
  /// müşteri bağlantıları kaldırılır.
  Future<void> deleteCustomer(String id) async {
    await _db.transaction((txn) async {
      final now = _now.toIso8601String();
      await txn.update(
        'projects',
        {'customer_id': null, 'updated_at': now},
        where: 'customer_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'calculations',
        {'customer_id': null},
        where: 'customer_id = ?',
        whereArgs: [id],
      );
      await txn.delete('customers', where: 'id = ?', whereArgs: [id]);
    });
  }

  // -------------------------------------------------------------- projeler

  Future<Project> saveProject({
    String? id,
    required String name,
    String? customerId,
    String location = '',
    String note = '',
    ProjectStatus status = ProjectStatus.preparing,
  }) async {
    if (customerId != null && await _customerById(customerId) == null) {
      throw const CalculationException('Seçilen müşteri bulunamadı.');
    }
    final now = _now;
    final existing = id == null ? null : await _projectById(id);
    final project = Project(
      id: existing?.id ?? ids.next(),
      name: name.trim(),
      customerId: customerId,
      location: location.trim(),
      note: note.trim(),
      status: status,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    project.validate();
    await _db.insert(
      'projects',
      _projectToRow(project),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return project;
  }

  /// Projeyi siler. Bağlı hesaplar **silinmez**; proje bağlantısı kaldırılır.
  Future<void> deleteProject(String id) async {
    await _db.transaction((txn) async {
      await txn.update(
        'calculations',
        {'project_id': null},
        where: 'project_id = ?',
        whereArgs: [id],
      );
      await txn.delete('projects', where: 'id = ?', whereArgs: [id]);
    });
  }

  // --------------------------------------------------------------- hesaplar

  /// Yeni hesap kaydeder (sürüm 1).
  Future<SavedCalculation> createCalculation({
    required String name,
    required CalcRevision revision,
    String? customerId,
    String? projectId,
  }) async {
    final now = _now;
    final calc = SavedCalculation(
      id: ids.next(),
      name: name.trim(),
      customerId: customerId,
      projectId: projectId,
      createdAt: now,
      updatedAt: now,
      current: revision.copyWith(number: 1, savedAt: now),
    );
    await _writeCalculation(calc, isNew: true);
    return calc;
  }

  /// Hesabı düzenler: **yeni sürüm** eklenir, önceki sürümler korunur.
  /// [revision] `null` ise yalnızca ad / müşteri / proje güncellenir.
  Future<SavedCalculation> updateCalculation(
    String id, {
    String? name,
    CalcRevision? revision,
    String? customerId,
    String? projectId,
    bool clearCustomer = false,
    bool clearProject = false,
  }) async {
    final existing = await _calculationById(id);
    if (existing == null) {
      throw const CalculationException('Hesap bulunamadı.');
    }
    final now = _now;
    final updated = existing.copyWith(
      name: name?.trim(),
      customerId: customerId,
      projectId: projectId,
      clearCustomer: clearCustomer,
      clearProject: clearProject,
      updatedAt: now,
      current: revision?.copyWith(
        number: existing.current.number + 1,
        savedAt: now,
      ),
    );
    await _writeCalculation(
      updated,
      isNew: false,
      addRevision: revision != null,
    );
    return updated;
  }

  /// Hesabın kopyasını oluşturur (güncel sürümüyle, sürüm 1 olarak).
  Future<SavedCalculation> duplicateCalculation(
    String id, {
    String? name,
  }) async {
    final existing = await _calculationById(id);
    if (existing == null) {
      throw const CalculationException('Hesap bulunamadı.');
    }
    return createCalculation(
      name: name ?? '${existing.name} (kopya)',
      revision: existing.current,
      customerId: existing.customerId,
      projectId: existing.projectId,
    );
  }

  /// Hesabı ve tüm sürümlerini siler.
  Future<void> deleteCalculation(String id) async {
    await _db.delete('calculations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _writeCalculation(
    SavedCalculation calc, {
    required bool isNew,
    bool addRevision = true,
  }) async {
    calc.validate();
    await _checkLinks(calc.customerId, calc.projectId);
    await _db.transaction((txn) async {
      final row = {
        'id': calc.id,
        'name': calc.name,
        'customer_id': calc.customerId,
        'project_id': calc.projectId,
        'created_at': calc.createdAt.toIso8601String(),
        'updated_at': calc.updatedAt.toIso8601String(),
        'current_revision': calc.current.number,
      };
      if (isNew) {
        await txn.insert('calculations', row);
      } else {
        await txn.update(
          'calculations',
          row,
          where: 'id = ?',
          whereArgs: [calc.id],
        );
      }
      if (isNew || addRevision) {
        await txn.insert('calculation_revisions', {
          'calculation_id': calc.id,
          'revision': calc.current.number,
          'saved_at': calc.current.savedAt.toIso8601String(),
          'payload': jsonEncode(calc.current.toJson()),
        });
      }
    });
  }

  Future<void> _checkLinks(String? customerId, String? projectId) async {
    if (customerId != null && await _customerById(customerId) == null) {
      throw const CalculationException('Seçilen müşteri bulunamadı.');
    }
    if (projectId != null && await _projectById(projectId) == null) {
      throw const CalculationException('Seçilen proje bulunamadı.');
    }
  }

  // ------------------------------------------------------- yedek / geri yükle

  /// Tüm kayıtları JSON olarak dışa aktarır. Okunamayan sürümler ham metin
  /// olarak eklenir; böylece yedekte de kaybolmaz.
  Future<Map<String, Object?>> exportBackup() async {
    final customers = await _db.query('customers');
    final projects = await _db.query('projects');
    final calcs = await _db.query('calculations');
    final revisions = await _db.query(
      'calculation_revisions',
      orderBy: 'calculation_id, revision',
    );
    return {
      'format': backupFormat,
      'backupVersion': backupVersion,
      'schemaVersion': AppDatabase.version,
      'exportedAt': _now.toIso8601String(),
      'customers': customers,
      'projects': projects,
      'calculations': [
        for (final c in calcs)
          {
            ...c,
            'revisions': [
              for (final r in revisions)
                if (r['calculation_id'] == c['id'])
                  {
                    'revision': r['revision'],
                    'saved_at': r['saved_at'],
                    'payload': r['payload'],
                  },
            ],
          },
      ],
    };
  }

  /// Yedeği geri yükler; mevcut kayıtların **yerine** geçer. Tek bir işlem
  /// (transaction) içinde çalışır: herhangi bir hata olursa hiçbir şey
  /// değişmez.
  Future<void> importBackup(Map<String, Object?> backup) async {
    if (backup['format'] != backupFormat) {
      throw const FormatException('Bu dosya bir UstaMetre yedeği değil.');
    }
    final version = backup['backupVersion'];
    if (version is! int || version > backupVersion) {
      throw const FormatException(
        'Yedek daha yeni bir uygulama sürümüyle alınmış.',
      );
    }
    List<Map<String, Object?>> list(String key) => [
      for (final e in (backup[key] as List?) ?? const [])
        (e! as Map).cast<String, Object?>(),
    ];

    await _db.transaction((txn) async {
      await txn.delete('calculation_revisions');
      await txn.delete('calculations');
      await txn.delete('projects');
      await txn.delete('customers');
      for (final c in list('customers')) {
        _customerFromRow(c); // biçim doğrulaması
        await txn.insert('customers', c);
      }
      for (final p in list('projects')) {
        _projectFromRow(p);
        await txn.insert('projects', p);
      }
      for (final c in list('calculations')) {
        final revs = [
          for (final r in (c['revisions'] as List?) ?? const [])
            (r! as Map).cast<String, Object?>(),
        ];
        await txn.insert('calculations', {
          for (final e in c.entries)
            if (e.key != 'revisions') e.key: e.value,
        });
        for (final r in revs) {
          await txn.insert('calculation_revisions', {
            'calculation_id': c['id'],
            'revision': r['revision'],
            'saved_at': r['saved_at'],
            'payload': r['payload'],
          });
        }
      }
    });
  }

  // ------------------------------------------------------------- dönüşümler

  Future<Customer?> _customerById(String id) async {
    final rows = await _db.query('customers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _customerFromRow(rows.first);
  }

  Future<Project?> _projectById(String id) async {
    final rows = await _db.query('projects', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _projectFromRow(rows.first);
  }

  Future<SavedCalculation?> _calculationById(String id) async {
    final rows = await _db.rawQuery(
      '''
      SELECT c.*, r.payload AS payload
      FROM calculations c
      LEFT JOIN calculation_revisions r
        ON r.calculation_id = c.id AND r.revision = c.current_revision
      WHERE c.id = ?''',
      [id],
    );
    return rows.isEmpty ? null : _calculationFromRow(rows.first);
  }

  static Map<String, Object?> _customerToRow(Customer c) => {
    'id': c.id,
    'name': c.name,
    'phone': c.phone,
    'email': c.email,
    'address': c.address,
    'note': c.note,
    'created_at': c.createdAt.toIso8601String(),
    'updated_at': c.updatedAt.toIso8601String(),
  };

  static Customer _customerFromRow(Map<String, Object?> r) => Customer(
    id: r['id']! as String,
    name: r['name']! as String,
    phone: (r['phone'] as String?) ?? '',
    email: (r['email'] as String?) ?? '',
    address: (r['address'] as String?) ?? '',
    note: (r['note'] as String?) ?? '',
    createdAt: DateTime.parse(r['created_at']! as String),
    updatedAt: DateTime.parse(r['updated_at']! as String),
  );

  static Map<String, Object?> _projectToRow(Project p) => {
    'id': p.id,
    'name': p.name,
    'customer_id': p.customerId,
    'location': p.location,
    'note': p.note,
    'status': p.status.name,
    'created_at': p.createdAt.toIso8601String(),
    'updated_at': p.updatedAt.toIso8601String(),
  };

  static Project _projectFromRow(Map<String, Object?> r) => Project(
    id: r['id']! as String,
    name: r['name']! as String,
    customerId: r['customer_id'] as String?,
    location: (r['location'] as String?) ?? '',
    note: (r['note'] as String?) ?? '',
    status: ProjectStatus.values.byName(r['status']! as String),
    createdAt: DateTime.parse(r['created_at']! as String),
    updatedAt: DateTime.parse(r['updated_at']! as String),
  );

  static CalcRevision _revisionFromPayload(String payload) =>
      CalcRevision.fromJson(
        (jsonDecode(payload) as Map).cast<String, Object?>(),
      );

  static SavedCalculation _calculationFromRow(Map<String, Object?> r) {
    final payload = r['payload'] as String?;
    if (payload == null) {
      throw const FormatException('Güncel sürüm kaydı bulunamadı.');
    }
    return SavedCalculation(
      id: r['id']! as String,
      name: r['name']! as String,
      customerId: r['customer_id'] as String?,
      projectId: r['project_id'] as String?,
      createdAt: DateTime.parse(r['created_at']! as String),
      updatedAt: DateTime.parse(r['updated_at']! as String),
      current: _revisionFromPayload(payload),
    );
  }
}
