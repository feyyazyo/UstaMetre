import 'dart:io';

import 'package:sqflite/sqflite.dart';

/// Bir şema sürümünden bir sonrakine geçiş adımı.
typedef Migration = Future<void> Function(DatabaseExecutor db);

/// UstaMetre yerel veritabanı (SQLite, cihazda; internet gerekmez).
///
/// Şema yalnızca sıralı geçişlerle (migration) kurulur: yeni kurulumda
/// tüm adımlar baştan, güncellemede yalnızca eksik adımlar çalışır. Böylece
/// güncellemeler mevcut kayıtları silmez. Var olan bir veritabanı
/// yükseltilmeden önce dosyanın yedeği alınır (`<dosya>.v<eski>.bak`).
abstract final class AppDatabase {
  /// Güncel şema sürümü = [migrations] uzunluğu.
  static int get version => migrations.length;

  /// `migrations[i]`: sürüm i → i+1.
  static final List<Migration> migrations = [_v1];

  static Future<Database> open(
    DatabaseFactory factory,
    String path, {
    List<Migration>? migrationList,
  }) async {
    final steps = migrationList ?? migrations;
    final target = steps.length;

    await _backupBeforeUpgrade(factory, path, target);

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: target,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          for (var i = 0; i < version; i++) {
            await steps[i](db);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          for (var i = oldVersion; i < newVersion; i++) {
            await steps[i](db);
          }
        },
        onDowngrade: (db, oldVersion, newVersion) => throw StateError(
          'Veritabanı daha yeni bir uygulama sürümüne ait (şema $oldVersion). '
          'Kayıtları korumak için açılmadı; uygulamayı güncelleyin.',
        ),
      ),
    );
  }

  static Future<void> _backupBeforeUpgrade(
    DatabaseFactory factory,
    String path,
    int target,
  ) async {
    if (path == inMemoryDatabasePath) return;
    final file = File(path);
    if (!await file.exists()) return;
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    final current = await db.getVersion();
    await db.close();
    if (current > 0 && current < target) {
      await file.copy('$path.v$current.bak');
    }
  }

  /// Şema 1: müşteriler, projeler, hesaplar ve hesap sürümleri.
  static Future<void> _v1(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        customer_id TEXT REFERENCES customers(id) ON DELETE SET NULL,
        location TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE calculations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        customer_id TEXT REFERENCES customers(id) ON DELETE SET NULL,
        project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        current_revision INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE calculation_revisions (
        calculation_id TEXT NOT NULL
          REFERENCES calculations(id) ON DELETE CASCADE,
        revision INTEGER NOT NULL,
        saved_at TEXT NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY (calculation_id, revision)
      )''');
    await db.execute(
      'CREATE INDEX idx_projects_customer ON projects(customer_id)',
    );
    await db.execute(
      'CREATE INDEX idx_calculations_project ON calculations(project_id)',
    );
    await db.execute(
      'CREATE INDEX idx_calculations_customer ON calculations(customer_id)',
    );
  }
}
