import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ustametre/data/db/app_database.dart';
import 'package:ustametre/data/records_repository.dart';
import 'package:ustametre/domain/records/project.dart';
import 'package:ustametre/domain/records/saved_calculation.dart';
import 'package:ustametre/engine/calculator.dart';
import 'package:ustametre/engine/calculators/measurement_calculator.dart';
import 'package:ustametre/engine/costing/cost_item.dart';
import 'package:ustametre/engine/costing/cost_sheet.dart';
import 'package:ustametre/engine/costing/price_list.dart';
import 'package:ustametre/engine/ids.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/engine/pricing.dart';

Decimal d(String s) => Decimal.parse(s);
Money tl(String s) => Money.fromDecimal(d(s));

/// Ölçü hesabından kaydedilebilir sürüm üretir.
CalcRevision revisionFor({
  String length = '2',
  String width = '1',
  String price = '1000',
  CostSheet extras = const CostSheet(),
  String categoryId = 'marble_granite',
}) {
  final input = MeasurementInput(
    type: MeasurementType.area,
    length: d(length),
    width: d(width),
    unitPrice: tl(price),
    vatPercent: d('20'),
    extras: extras,
    discount: PercentDiscount(d('5')),
  );
  return CalcRevision(
    number: 1,
    savedAt: DateTime.utc(2026),
    categoryId: categoryId,
    kind: CalcKind.quick,
    modeLabel: 'Alan (m²)',
    inputs: {
      'mode': 'area',
      'unit': 'meter',
      'fields': {'length': length, 'width': width, 'unitPrice': price},
      'extras': extras.toJson(),
    },
    result: const MeasurementCalculator().calculate(input),
  );
}

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  late Directory dir;
  late String path;
  var now = DateTime.utc(2026, 11, 18, 9);

  Future<RecordsRepository> open() => RecordsRepository.open(
    factory,
    path,
    ids: SequentialIdGenerator('r${DateTime.now().microsecondsSinceEpoch}-'),
    clock: () => now,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ustametre_db_');
    path = '${dir.path}/ustametre.db';
    now = DateTime.utc(2026, 11, 18, 9);
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  group('Hesap kaydetme', () {
    test('kaydet, yeniden aç: tüm alanlar ve tutarlar korunur', () async {
      final repo = await open();
      final rev = revisionFor();
      final saved = await repo.createCalculation(
        name: 'Mutfak tezgâhı',
        revision: rev,
      );
      await repo.close();

      // Uygulama yeniden başlatıldı.
      final again = await open();
      final snap = await again.loadAll();
      final c = snap.calculations.single;
      expect(c.id, saved.id);
      expect(c.name, 'Mutfak tezgâhı');
      expect(c.categoryId, 'marble_granite');
      expect(c.kind, CalcKind.quick);
      expect(c.current.modeLabel, 'Alan (m²)');
      expect(c.createdAt, now);
      expect(c.revisionNumber, 1);
      expect(c.customerId, isNull);
      expect(c.projectId, isNull);
      expect(c.current.inputs['fields'], {
        'length': '2',
        'width': '1',
        'unitPrice': '1000',
      });
      final p = c.current.result.price!;
      expect(p.subtotal, rev.result.price!.subtotal);
      expect(p.discount, tl('100'));
      expect(p.vatPercent, d('20'));
      expect(p.grandTotal, tl('2280')); // (2000 − 100) × 1,2
      expect(p.discountRule, isA<PercentDiscount>());
      expect(c.current.result.steps, rev.result.steps);
      expect(snap.corrupt, isEmpty);
      await again.close();
    });

    test('fiyat listesi değişince kayıtlı hesabın tutarı değişmez', () async {
      var list = const PriceList().add(
        PriceListItem.create(
          id: 'evye',
          name: 'Evye montajı',
          category: CostKind.labor,
          unit: CostUnit.piece,
          price: tl('750'),
          at: DateTime.utc(2026),
        ),
      );
      final extras = const CostSheet().add(
        list.byId('evye')!.toCostItem(id: 'x1'),
      );
      final repo = await open();
      await repo.createCalculation(
        name: 'Evyeli tezgâh',
        revision: revisionFor(extras: extras),
      );

      list = list.updatePrice('evye', tl('1500'), at: DateTime.utc(2026, 6));
      expect(list.byId('evye')!.price, tl('1500'));

      await repo.close();
      final again = await open();
      final c = (await again.loadAll()).calculations.single;
      final line = c.current.result.price!.lines.firstWhere(
        (l) => l.label == 'Evye montajı',
      );
      expect(line.unitPrice, tl('750'));
      expect(line.amount, tl('750'));
      // (2000 + 750 − %5) × 1,2 = 3135
      expect(c.grandTotal, tl('3135'));
      final storedItem = CostItem.fromJson(
        ((c.current.inputs['extras']! as List).single! as Map)
            .cast<String, Object?>(),
      );
      expect(storedItem.unitPrice, tl('750'));
      await again.close();
    });

    test('müşteri ve proje olmadan kaydedilebilir; ad zorunlu', () async {
      final repo = await open();
      final c = await repo.createCalculation(
        name: 'Bağımsız',
        revision: revisionFor(),
      );
      expect(c.customerId, isNull);
      expect(c.projectId, isNull);
      expect(
        () => repo.createCalculation(name: '  ', revision: revisionFor()),
        throwsA(isA<CalculationException>()),
      );
      await repo.close();
    });

    test('olmayan müşteri/proje bağlantısı reddedilir', () async {
      final repo = await open();
      expect(
        () => repo.createCalculation(
          name: 'X',
          revision: revisionFor(),
          projectId: 'yok',
        ),
        throwsA(isA<CalculationException>()),
      );
      await repo.close();
    });
  });

  group('Düzenleme, sürümler, kopyalama, silme', () {
    test('düzenleme yeni sürüm ekler; eski sürüm kaybolmaz', () async {
      final repo = await open();
      final c = await repo.createCalculation(
        name: 'Tezgâh',
        revision: revisionFor(),
      );
      now = DateTime.utc(2026, 11, 19);
      final edited = await repo.updateCalculation(
        c.id,
        name: 'Tezgâh (revize)',
        revision: revisionFor(length: '3'),
      );
      expect(edited.revisionNumber, 2);
      expect(edited.createdAt, DateTime.utc(2026, 11, 18, 9));
      expect(edited.updatedAt, now);

      final revs = await repo.revisions(c.id);
      expect(revs.map((r) => r.number), [1, 2]);
      expect(revs.first.grandTotal, tl('2280'));
      expect(revs.last.grandTotal, tl('3420')); // 3000 × 0,95 × 1,2

      final snap = await repo.loadAll();
      expect(snap.calculations.single.name, 'Tezgâh (revize)');
      expect(snap.calculations.single.grandTotal, tl('3420'));

      // Yalnızca ad değişikliği yeni sürüm oluşturmaz.
      await repo.updateCalculation(c.id, name: 'Tezgâh v2');
      expect(await repo.revisions(c.id), hasLength(2));
      await repo.close();
    });

    test(
      'kopyalama: yeni kimlik, "(kopya)" adı, aynı tutar, sürüm 1',
      () async {
        final repo = await open();
        final c = await repo.createCalculation(
          name: 'A',
          revision: revisionFor(),
        );
        await repo.updateCalculation(c.id, revision: revisionFor(length: '4'));
        final copy = await repo.duplicateCalculation(c.id);
        expect(copy.id, isNot(c.id));
        expect(copy.name, 'A (kopya)');
        expect(copy.revisionNumber, 1);
        expect(copy.grandTotal, tl('4560'));
        expect((await repo.loadAll()).calculations, hasLength(2));
        await repo.close();
      },
    );

    test(
      'silme hesabı ve sürümlerini kaldırır, diğerlerine dokunmaz',
      () async {
        final repo = await open();
        final a = await repo.createCalculation(
          name: 'A',
          revision: revisionFor(),
        );
        final b = await repo.createCalculation(
          name: 'B',
          revision: revisionFor(),
        );
        await repo.updateCalculation(a.id, revision: revisionFor(length: '5'));
        await repo.deleteCalculation(a.id);
        final snap = await repo.loadAll();
        expect(snap.calculations.single.id, b.id);
        expect(await repo.revisions(a.id), isEmpty);
        await repo.close();
      },
    );
  });

  group('Müşteri ve proje', () {
    test(
      'müşteri oluştur ve düzenle; isteğe bağlı alanlar boş olabilir',
      () async {
        final repo = await open();
        final c = await repo.saveCustomer(name: 'Ayşe Yılmaz');
        expect(c.phone, '');
        expect(c.email, '');
        now = DateTime.utc(2026, 12);
        final edited = await repo.saveCustomer(
          id: c.id,
          name: 'Ayşe Yılmaz',
          phone: '0555 111 22 33',
          email: 'ayse@example.com',
          address: 'Kadıköy',
        );
        expect(edited.createdAt, c.createdAt);
        expect(edited.updatedAt, now);
        final snap = await repo.loadAll();
        expect(snap.customers.single.phone, '0555 111 22 33');
        expect(
          () => repo.saveCustomer(name: ''),
          throwsA(isA<CalculationException>()),
        );
        expect(
          () => repo.saveCustomer(name: 'X', email: 'gecersiz'),
          throwsA(isA<CalculationException>()),
        );
        await repo.close();
      },
    );

    test(
      'bir müşteriye birden fazla proje, bir projeye birden fazla hesap',
      () async {
        final repo = await open();
        final musteri = await repo.saveCustomer(name: 'Demir İnşaat');
        final mutfak = await repo.saveProject(
          name: 'Mutfak',
          customerId: musteri.id,
        );
        final banyo = await repo.saveProject(
          name: 'Banyo',
          customerId: musteri.id,
          status: ProjectStatus.quoted,
        );
        for (final n in ['Tezgâh', 'Denizlik', 'Süpürgelik']) {
          await repo.createCalculation(
            name: n,
            revision: revisionFor(),
            projectId: mutfak.id,
            customerId: musteri.id,
          );
        }
        await repo.createCalculation(
          name: 'Lavabo tezgâhı',
          revision: revisionFor(),
          projectId: banyo.id,
        );
        final snap = await repo.loadAll();
        expect(
          snap.projects.where((p) => p.customerId == musteri.id),
          hasLength(2),
        );
        expect(
          snap.calculations
              .where((c) => c.projectId == mutfak.id)
              .map((c) => c.name),
          unorderedEquals(['Tezgâh', 'Denizlik', 'Süpürgelik']),
        );
        expect(
          snap.projects.firstWhere((p) => p.id == banyo.id).status,
          ProjectStatus.quoted,
        );
        await repo.close();
      },
    );

    test(
      'müşteri silinince projeler ve hesaplar korunur, bağ kaldırılır',
      () async {
        final repo = await open();
        final m = await repo.saveCustomer(name: 'Silinecek');
        final p = await repo.saveProject(name: 'Proje', customerId: m.id);
        await repo.createCalculation(
          name: 'Hesap',
          revision: revisionFor(),
          customerId: m.id,
          projectId: p.id,
        );
        await repo.deleteCustomer(m.id);
        final snap = await repo.loadAll();
        expect(snap.customers, isEmpty);
        expect(snap.projects.single.customerId, isNull);
        expect(snap.calculations.single.customerId, isNull);
        expect(snap.calculations.single.projectId, p.id);
        await repo.close();
      },
    );

    test('proje silinince hesaplar korunur, proje bağı kaldırılır', () async {
      final repo = await open();
      final p = await repo.saveProject(name: 'Proje');
      await repo.createCalculation(
        name: 'Hesap',
        revision: revisionFor(),
        projectId: p.id,
      );
      await repo.deleteProject(p.id);
      final snap = await repo.loadAll();
      expect(snap.projects, isEmpty);
      expect(snap.calculations.single.projectId, isNull);
      await repo.close();
    });
  });

  group('Veri güvenliği', () {
    test('bozuk kayıt silinmez; diğer kayıtlar okunur', () async {
      final repo = await open();
      final good = await repo.createCalculation(
        name: 'İyi',
        revision: revisionFor(),
      );
      final bad = await repo.createCalculation(
        name: 'Bozuk',
        revision: revisionFor(),
      );
      await repo.close();

      final raw = await factory.openDatabase(path);
      await raw.update(
        'calculation_revisions',
        {'payload': '{bozuk json'},
        where: 'calculation_id = ?',
        whereArgs: [bad.id],
      );
      await raw.close();

      final again = await open();
      final snap = await again.loadAll();
      expect(snap.calculations.single.id, good.id);
      expect(snap.corrupt.single.id, bad.id);
      // Kayıt hâlâ veritabanında ve yedekte.
      final backup = await again.exportBackup();
      final calcs = backup['calculations']! as List;
      expect(calcs, hasLength(2));
      await again.close();
    });

    test('daha yeni biçimli kayıt okunamaz ama silinmez', () async {
      final repo = await open();
      final c = await repo.createCalculation(
        name: 'Yeni',
        revision: revisionFor(),
      );
      await repo.close();
      final raw = await factory.openDatabase(path);
      final row = (await raw.query('calculation_revisions')).single;
      final json =
          jsonDecode(row['payload']! as String) as Map<String, Object?>;
      json['schema'] = 99;
      await raw.update('calculation_revisions', {'payload': jsonEncode(json)});
      await raw.close();
      final again = await open();
      final snap = await again.loadAll();
      expect(snap.calculations, isEmpty);
      expect(snap.corrupt.single.id, c.id);
      expect(snap.corrupt.single.error, contains('daha yeni'));
      await again.close();
    });

    test('yedek dışa aktar → geri yükle aynı kayıtları verir', () async {
      final repo = await open();
      final m = await repo.saveCustomer(name: 'Yedek Müşteri', phone: '1');
      final p = await repo.saveProject(name: 'Yedek Proje', customerId: m.id);
      final c = await repo.createCalculation(
        name: 'Yedek Hesap',
        revision: revisionFor(),
        projectId: p.id,
      );
      await repo.updateCalculation(c.id, revision: revisionFor(length: '3'));
      final backup = jsonDecode(
        jsonEncode(await repo.exportBackup()),
      ) as Map<String, Object?>;
      expect(backup['schemaVersion'], AppDatabase.version);

      await repo.deleteCalculation(c.id);
      await repo.deleteCustomer(m.id);
      await repo.importBackup(backup);

      final snap = await repo.loadAll();
      expect(snap.customers.single.name, 'Yedek Müşteri');
      expect(snap.projects.single.customerId, m.id);
      expect(snap.calculations.single.revisionNumber, 2);
      expect(await repo.revisions(c.id), hasLength(2));
      await repo.close();
    });

    test('geçersiz yedek hiçbir şeyi değiştirmez', () async {
      final repo = await open();
      await repo.saveCustomer(name: 'Kalmalı');
      await expectLater(
        repo.importBackup({'format': 'baska'}),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        repo.importBackup({
          'format': RecordsRepository.backupFormat,
          'backupVersion': 1,
          'customers': [
            {'id': 'x'}, // eksik alanlar
          ],
        }),
        throwsA(anything),
      );
      expect((await repo.loadAll()).customers.single.name, 'Kalmalı');
      await repo.close();
    });
  });

  group('Veritabanı sürüm yükseltme', () {
    test('yeni sürüm şeması kayıtları silmeden uygulanır ve yedek alınır', () async {
      // Sürüm 1 veritabanı ve kayıtları
      final v1 = await open();
      final m = await v1.saveCustomer(name: 'Eski müşteri');
      await v1.createCalculation(
        name: 'Eski hesap',
        revision: revisionFor(),
        customerId: m.id,
      );
      await v1.close();

      // Sürüm 2: varsayımsal yeni sütun
      Future<void> v2(DatabaseExecutor db) => db.execute(
        "ALTER TABLE customers ADD COLUMN tax_number TEXT NOT NULL DEFAULT ''",
      );
      final db = await AppDatabase.open(
        factory,
        path,
        migrationList: [...AppDatabase.migrations, v2],
      );
      expect(await db.getVersion(), 2);
      final customers = await db.query('customers');
      expect(customers.single['name'], 'Eski müşteri');
      expect(customers.single['tax_number'], '');
      expect((await db.query('calculations')).single['name'], 'Eski hesap');
      await db.close();

      // Yükseltmeden önce sürüm 1 dosyasının yedeği alındı.
      expect(await File('$path.v1.bak').exists(), isTrue);
    });

    test('daha yeni şemalı veritabanı açılmaz ve silinmez', () async {
      Future<void> v2(DatabaseExecutor db) =>
          db.execute('CREATE TABLE future_table (id TEXT)');
      final newer = await AppDatabase.open(
        factory,
        path,
        migrationList: [...AppDatabase.migrations, v2],
      );
      await newer.insert('customers', {
        'id': 'k',
        'name': 'Korunacak',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });
      await newer.close();

      await expectLater(open(), throwsA(isA<StateError>()));

      final check = await factory.openDatabase(path);
      expect((await check.query('customers')).single['name'], 'Korunacak');
      await check.close();
    });

    test('kayıt biçimi 0 (sürüm alanı yok) güncel biçime taşınır', () {
      final json = revisionFor().toJson()
        ..remove('schema')
        ..remove('modeLabel')
        ..remove('note');
      final rev = CalcRevision.fromJson(json);
      expect(rev.modeLabel, '');
      expect(rev.note, '');
      expect(rev.grandTotal, tl('2280'));
    });
  });
}
