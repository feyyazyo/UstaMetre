import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustametre/app/app.dart';
import 'package:ustametre/data/records_controller.dart';
import 'package:ustametre/engine/costing/cost_item.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/engine/pricing.dart';
import 'package:ustametre/features/calculations/calculation_page.dart';
import 'package:ustametre/features/calculations/marble/marble_project_page.dart';
import 'package:ustametre/features/calculations/pvc/pvc_project_page.dart';
import 'package:ustametre/features/customers/customers_page.dart';
import 'package:ustametre/features/projects/projects_page.dart';
import 'package:ustametre/features/records/calculation_detail_page.dart';
import 'package:ustametre/features/records/history_page.dart';

import '../helpers.dart';

Money tl(String s) => Money.fromDecimal(Decimal.parse(s));

/// Seramik, adet modu: birim fiyat girilince sonuç hazır olur.
Future<void> quickPiece(
  WidgetTester tester,
  String price, {
  String qty = '1',
}) async {
  await tapKey(tester, 'mode_piece');
  await enterKey(tester, 'field_quantity', qty);
  await enterKey(tester, 'field_unitPrice', price);
}

/// Üst çubuktaki Kaydet → kayıt sayfası.
Future<void> openSave(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('save_calculation')));
  await tester.pumpAndSettle();
}

Future<void> setName(WidgetTester tester, String name) async {
  final field = await reveal(tester, 'save_name', up: true);
  await tester.enterText(field, name);
  await tester.pump();
}

Future<void> confirmSave(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('save_calc_top')));
  await tester.pumpAndSettle();
}

Future<void> chooseInDropdown(
  WidgetTester tester,
  String key,
  String option,
) async {
  await tapKey(tester, key);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  group('Hesap kaydetme ve geçmiş', () {
    testWidgets('müşteri/proje olmadan kaydet; geçmişte görünür ve açılır', (
      tester,
    ) async {
      final records = await testRecords(tester);
      await pumpScreen(
        tester,
        const CalculationPage(initialCategoryId: 'ceramic_tile'),
        records: records,
      );

      // Sonuç yokken (ölçüsüz alan hesabı) Kaydet açıklama verir.
      await tapKey(tester, 'mode_area');
      await openSave(tester);
      expect(find.byKey(const ValueKey('save_name')), findsNothing);
      expect(find.textContaining('önce hesabı tamamlayın'), findsOneWidget);

      await tapKey(tester, 'mode_piece', up: true);
      await enterKey(tester, 'field_unitPrice', '250');
      await openSave(tester);
      expect(find.text('Hesabı kaydet'), findsOneWidget);
      expect(find.text('Müşteri yok'), findsOneWidget);
      expect(find.text('Proje yok'), findsOneWidget);
      await setName(tester, 'Banyo fayans');
      await confirmSave(tester);

      expect(find.textContaining('"Banyo fayans" kaydedildi'), findsOneWidget);
      final saved = records.calculations.single;
      expect(saved.name, 'Banyo fayans');
      expect(saved.customerId, isNull);
      expect(saved.projectId, isNull);
      expect(saved.grandTotal, tl('300')); // 250 + %20
      expect(saved.current.inputs['fields'], {
        'quantity': '1',
        'waste': '',
        'unitPrice': '250',
      });

      // Geçmiş → ayrıntı
      await pumpScreen(tester, const HistoryPage(), records: records);
      expect(find.text('Hesap Geçmişi (1)'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('calc_${saved.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(CalculationDetailPage), findsOneWidget);
      expect(find.text('Müşteri bağlı değil'), findsOneWidget);
      expect(find.text('Proje bağlı değil'), findsOneWidget);
      await reveal(tester, 'grand_total');
      expect(inKey('grand_total', '₺300,00'), findsOneWidget);
    });

    testWidgets('düzenleme yeni sürüm oluşturur, eski sürüm görülebilir', (
      tester,
    ) async {
      final records = await testRecords(tester);
      await pumpScreen(
        tester,
        const CalculationPage(initialCategoryId: 'ceramic_tile'),
        records: records,
      );
      await quickPiece(tester, '100');
      await openSave(tester);
      await setName(tester, 'Denizlik');
      await confirmSave(tester);
      final id = records.calculations.single.id;

      await pumpScreen(tester, CalculationDetailPage(id: id), records: records);
      await tester.tap(find.byKey(const ValueKey('detail_edit')));
      await tester.pumpAndSettle();
      // Girdiler kayıttan yüklendi.
      final priceField = await reveal(tester, 'field_unitPrice');
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: priceField, matching: find.byType(TextField)),
            )
            .controller!
            .text,
        '100',
      );
      await tester.enterText(priceField, '150');
      await tester.pump();
      await openSave(tester);
      expect(find.text('Sürüm 2 olarak kaydet'), findsOneWidget);
      await confirmSave(tester);
      expect(find.textContaining('sürüm 2'), findsOneWidget);
      expect(find.textContaining('Önceki sürüm korundu'), findsOneWidget);

      final calc = records.calculationById(id)!;
      expect(calc.revisionNumber, 2);
      expect(calc.grandTotal, tl('180'));
      final revs = await tester.runAsync(() => records.revisions(id));
      expect(revs!.map((r) => r.grandTotal), [tl('120'), tl('180')]);

      // Ayrıntıda sürüm geçmişi
      await pumpScreen(tester, CalculationDetailPage(id: id), records: records);
      // Sürüm listesi asenkron yüklenir; gerçek zamanda tamamlanmasını bekle.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      await reveal(tester, 'revision_1');
      expect(find.text('Sürüm 2 (güncel)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('revision_1')));
      await tester.pumpAndSettle();
      expect(find.text('Denizlik · Sürüm 1'), findsOneWidget);
      await reveal(tester, 'grand_total');
      expect(inKey('grand_total', '₺120,00'), findsOneWidget);
    });

    testWidgets(
      'düzenlerken "ayrı yeni hesap" seçilirse eski hesap aynı kalır',
      (tester) async {
        final records = await testRecords(tester);
        await pumpScreen(
          tester,
          const CalculationPage(initialCategoryId: 'ceramic_tile'),
          records: records,
        );
        await quickPiece(tester, '100');
        await openSave(tester);
        await setName(tester, 'Orijinal');
        await confirmSave(tester);
        await enterKey(tester, 'field_unitPrice', '999');
        await openSave(tester);
        await tapKey(tester, 'save_as_new');
        await setName(tester, 'Varyant');
        await confirmSave(tester);
        expect(records.calculations, hasLength(2));
        final original = records.calculations.firstWhere(
          (c) => c.name == 'Orijinal',
        );
        expect(original.revisionNumber, 1);
        expect(original.grandTotal, tl('120'));
      },
    );

    testWidgets('kopyala ve onaylı sil', (tester) async {
      final records = await testRecords(tester);
      await pumpScreen(
        tester,
        const CalculationPage(initialCategoryId: 'ceramic_tile'),
        records: records,
      );
      await quickPiece(tester, '100');
      await openSave(tester);
      await setName(tester, 'Süpürgelik');
      await confirmSave(tester);
      final id = records.calculations.single.id;

      await pumpScreen(tester, CalculationDetailPage(id: id), records: records);
      await tester.tap(find.byKey(const ValueKey('detail_copy')));
      await tester.pumpAndSettle();
      expect(records.calculations, hasLength(2));
      expect(find.text('Süpürgelik (kopya)'), findsWidgets);

      // Sil → Vazgeç: hiçbir şey silinmez.
      await tester.tap(find.byKey(const ValueKey('detail_delete')));
      await tester.pumpAndSettle();
      expect(find.text('Hesap silinsin mi?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm_cancel')));
      await tester.pumpAndSettle();
      expect(records.calculations, hasLength(2));

      // Sil → Onayla
      await tester.tap(find.byKey(const ValueKey('detail_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm_ok')));
      await tester.pumpAndSettle();
      expect(records.calculations.single.name, 'Süpürgelik');
    });

    testWidgets('geçmişte arama, meslek filtresi ve tarih sıralaması', (
      tester,
    ) async {
      final records = await testRecords(tester);
      final controller = records;
      Future<void> save(String category, String name) async {
        await pumpScreen(
          tester,
          CalculationPage(initialCategoryId: category),
          records: controller,
        );
        await quickPiece(tester, '10');
        await openSave(tester);
        await setName(tester, name);
        await confirmSave(tester);
      }

      await save('ceramic_tile', 'Mutfak fayans');
      await save('paint', 'Salon boya');
      await save('ceramic_tile', 'Banyo fayans');

      await pumpScreen(tester, const HistoryPage(), records: controller);
      expect(find.text('Hesap Geçmişi (3)'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('history_search')),
        'fayans',
      );
      await tester.pump();
      expect(find.text('Mutfak fayans'), findsOneWidget);
      expect(find.text('Banyo fayans'), findsOneWidget);
      expect(find.text('Salon boya'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('history_search')), '');
      await tester.pump();
      await chooseInDropdown(tester, 'history_category', 'Boya ve badana');
      expect(find.text('Salon boya'), findsOneWidget);
      expect(find.text('Mutfak fayans'), findsNothing);

      await chooseInDropdown(tester, 'history_category', 'Tümü');
      await tester.enterText(
        find.byKey(const ValueKey('history_search')),
        'olmayan',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('history_no_match')), findsOneWidget);
    });

    testWidgets('boş geçmiş yönlendirici açıklama gösterir', (tester) async {
      await pumpScreen(tester, const HistoryPage());
      expect(find.byKey(const ValueKey('history_empty')), findsOneWidget);
      expect(find.textContaining('"Kaydet"'), findsOneWidget);
    });
  });

  group('Müşteri ve proje', () {
    testWidgets(
      'kaydederken yeni müşteri ve proje oluştur; ekranlardan görülür',
      (tester) async {
        final records = await testRecords(tester);
        await pumpScreen(
          tester,
          const CalculationPage(initialCategoryId: 'ceramic_tile'),
          records: records,
        );
        await quickPiece(tester, '100');
        await openSave(tester);
        await setName(tester, 'Tezgâh');

        await chooseInDropdown(
          tester,
          'save_customer',
          '＋ Yeni müşteri oluştur',
        );
        await tester.enterText(
          find.byKey(const ValueKey('cust_name')),
          'Ali Kaya',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('cust_save_top')));
        await tester.pumpAndSettle();
        expect(find.text('Ali Kaya'), findsOneWidget); // seçildi

        await chooseInDropdown(
          tester,
          'project_picker',
          '＋ Yeni proje oluştur',
        );
        await tester.enterText(
          find.byKey(const ValueKey('proj_name')),
          'Mutfak',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('proj_save_top')));
        await tester.pumpAndSettle();
        await confirmSave(tester);

        final customer = records.customers.single;
        final project = records.projects.single;
        final calc = records.calculations.single;
        expect(project.customerId, customer.id); // proje müşteriye bağlandı
        expect(calc.customerId, customer.id);
        expect(calc.projectId, project.id);

        await pumpScreen(
          tester,
          CustomerDetailPage(id: customer.id),
          records: records,
        );
        expect(find.text('Projeler (1)'), findsOneWidget);
        expect(find.text('Hesaplar (1)'), findsOneWidget);
        expect(
          find.text('Mutfak'),
          findsWidgets,
        ); // proje kartı + hesap etiketi
        expect(find.text('Tezgâh'), findsOneWidget);

        await pumpScreen(
          tester,
          ProjectDetailPage(id: project.id),
          records: records,
        );
        expect(find.text('Hesaplar (1)'), findsOneWidget);
        expect(inKey('project_total', 'Toplam: ₺120,00'), findsNothing);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('project_total'))).data,
          'Toplam: ₺120,00',
        );
      },
    );

    testWidgets(
      'müşteri ekle, düzenle, ara; isteğe bağlı alanlar boş kalabilir',
      (tester) async {
        final records = await testRecords(tester);
        await pumpScreen(tester, const CustomersPage(), records: records);
        expect(find.byKey(const ValueKey('customers_empty')), findsOneWidget);

        Future<void> addCustomer(String name, {String phone = ''}) async {
          await tester.tap(find.byKey(const ValueKey('add_customer')));
          await tester.pumpAndSettle();
          await tester.enterText(find.byKey(const ValueKey('cust_name')), name);
          await tester.enterText(
            find.byKey(const ValueKey('cust_phone')),
            phone,
          );
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('cust_save_top')));
          await tester.pumpAndSettle();
        }

        await addCustomer('Demir Ltd.', phone: '0555 000 00 00');
        await addCustomer('Ayşe Yılmaz');
        expect(records.customers, hasLength(2));
        expect(
          records.customers.firstWhere((c) => c.name == 'Ayşe Yılmaz').phone,
          '',
        );

        await tester.enterText(
          find.byKey(const ValueKey('customer_search')),
          '0555',
        );
        await tester.pump();
        expect(find.text('Demir Ltd.'), findsOneWidget);
        expect(find.text('Ayşe Yılmaz'), findsNothing);

        // Düzenle
        final demir = records.customers.firstWhere(
          (c) => c.name == 'Demir Ltd.',
        );
        await tester.tap(find.byKey(ValueKey('customer_${demir.id}')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('customer_edit')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('cust_name')),
          'Demir İnşaat Ltd.',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('cust_save_top')));
        await tester.pumpAndSettle();
        expect(find.text('Demir İnşaat Ltd.'), findsOneWidget);

        // Boş adla kaydedilemez
        await tester.tap(find.byKey(const ValueKey('customer_edit')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('cust_name')), ' ');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('cust_save_top')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('cust_error')), findsOneWidget);
      },
    );

    testWidgets('müşteri silinince projeler ve hesaplar korunur', (
      tester,
    ) async {
      final records = await testRecords(tester);
      final c = (await tester.runAsync(
        () => records.saveCustomer(name: 'Silinecek'),
      ))!;
      final p = (await tester.runAsync(
        () => records.saveProject(name: 'Proje A', customerId: c.id),
      ))!;
      await pumpScreen(
        tester,
        CalculationPage(
          initialCategoryId: 'ceramic_tile',
          presetProjectId: p.id,
        ),
        records: records,
      );
      await quickPiece(tester, '100');
      await openSave(tester);
      expect(find.text('Proje A · Silinecek'), findsOneWidget); // ön seçili
      await confirmSave(tester);
      expect(records.calculations.single.customerId, c.id);

      await pumpScreen(tester, CustomerDetailPage(id: c.id), records: records);
      await tester.tap(find.byKey(const ValueKey('customer_delete')));
      await tester.pumpAndSettle();
      expect(find.textContaining('SİLİNMEZ'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm_ok')));
      await tester.pumpAndSettle();

      expect(records.customers, isEmpty);
      expect(records.projects.single.customerId, isNull);
      expect(records.calculations.single.customerId, isNull);
      expect(records.calculations.single.projectId, p.id);
    });

    testWidgets('bir projeye birden fazla hesap; projeden hesap ekle', (
      tester,
    ) async {
      final records = await testRecords(tester);
      final p = (await tester.runAsync(
        () => records.saveProject(name: 'Mutfak'),
      ))!;
      await pumpScreen(tester, ProjectDetailPage(id: p.id), records: records);
      expect(find.text('Bu projede hesap yok'), findsOneWidget);

      for (final (name, price) in [
        ('Tezgâh', '100'),
        ('Denizlik', '50'),
        ('Süpürgelik', '25'),
      ]) {
        await tester.tap(find.byKey(const ValueKey('project_copy')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('new_calc_quick')));
        await tester.pumpAndSettle();
        await quickPiece(tester, price);
        await openSave(tester);
        await setName(tester, name);
        await confirmSave(tester);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      expect(find.text('Hesaplar (3)'), findsOneWidget);
      expect(records.calculationsOfProject(p.id), hasLength(3));
      // (100 + 50 + 25) × 1,2
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('project_total'))).data,
        'Toplam: ₺210,00',
      );

      // Durum değiştir
      await tapKey(tester, 'project_status', up: true);
      await tester.tap(find.text('Onaylandı').last);
      await tester.pumpAndSettle();
      expect(records.projectById(p.id)!.status.label, 'Onaylandı');
    });

    testWidgets('proje ekle, durum filtresi ve arama', (tester) async {
      final records = await testRecords(tester);
      await pumpScreen(tester, const ProjectsPage(), records: records);
      expect(find.byKey(const ValueKey('projects_empty')), findsOneWidget);
      for (final name in ['Mutfak', 'Banyo']) {
        await tester.tap(find.byKey(const ValueKey('add_project')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('proj_name')), name);
        await tester.pump();
        if (name == 'Banyo') {
          await chooseInDropdown(tester, 'proj_status', 'Tamamlandı');
        }
        await tester.tap(find.byKey(const ValueKey('proj_save_top')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Projeler (2)'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('status_filter_completed')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('status_filter_completed')));
      await tester.pumpAndSettle();
      expect(find.text('Banyo'), findsOneWidget);
      expect(find.text('Mutfak'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('status_filter_all')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('status_filter_all')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('project_search')),
        'mut',
      );
      await tester.pump();
      expect(find.text('Mutfak'), findsOneWidget);
      expect(find.text('Banyo'), findsNothing);
    });
  });

  group('Proje hesaplarını kaydet ve düzenlemek için aç', () {
    testWidgets('mermer: parçalar, kenarlar ve fiyatlar geri yüklenir', (
      tester,
    ) async {
      final records = await testRecords(tester);
      await pumpScreen(tester, const MarbleProjectPage(), records: records);
      for (final (len, dep) in [('250', '62'), ('120', '62')]) {
        await tapKey(tester, 'add_piece');
        await tester.enterText(find.byKey(const ValueKey('piece_length')), len);
        await tester.enterText(find.byKey(const ValueKey('piece_depth')), dep);
        await tester.pump();
        await tapKey(tester, 'edge_sakal_front');
        await tester.tap(find.byKey(const ValueKey('piece_save_top')));
        await tester.pumpAndSettle();
      }
      await enterKey(tester, 'field_materialPrice', '1.000');
      await enterKey(tester, 'field_edge_sakal', '200');
      // 2,294 m² × 1000 + 3,7 mtül × 200 = 3.034 → %20 KDV
      expect(bar('₺3.640,80'), findsOneWidget);
      await openSave(tester);
      await setName(tester, 'L tezgâh');
      await confirmSave(tester);
      final calc = records.calculations.single;
      expect(calc.current.modeLabel, 'Tezgâh projesi (2 parça)');

      await pumpScreen(
        tester,
        CalculationDetailPage(id: calc.id),
        records: records,
      );
      await tester.tap(find.byKey(const ValueKey('detail_edit')));
      await tester.pumpAndSettle();
      expect(find.byType(MarbleProjectPage), findsOneWidget);
      expect(await revealText(tester, 'Tezgâh parçaları (2)'), findsOneWidget);
      expect(bar('₺3.640,80'), findsOneWidget); // aynı girdiler, aynı tutar
    });

    testWidgets('PVC: doğrama kalemleri ve türleri geri yüklenir', (
      tester,
    ) async {
      final records = await testRecords(tester);
      await pumpScreen(tester, const PvcProjectPage(), records: records);
      await tapKey(tester, 'add_door');
      for (final (key, v) in [
        ('j_width', '90'),
        ('j_height', '210'),
        ('j_glassPrice', '100'),
      ]) {
        final f = await reveal(tester, key);
        await tester.enterText(f, v);
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('j_save_top')));
      await tester.pumpAndSettle();
      await openSave(tester);
      await setName(tester, 'Giriş kapısı');
      await confirmSave(tester);
      final calc = records.calculations.single;
      expect(calc.kind.name, 'pvcProject');

      await pumpScreen(
        tester,
        CalculationDetailPage(id: calc.id),
        records: records,
      );
      await tester.tap(find.byKey(const ValueKey('detail_edit')));
      await tester.pumpAndSettle();
      expect(find.byType(PvcProjectPage), findsOneWidget);
      expect(await revealText(tester, 'Kapı 1'), findsOneWidget);
      expect(bar(calc.grandTotal!.format()), findsOneWidget);
    });
  });

  group('Kalıcılık ve fiyat güvenliği', () {
    testWidgets('fiyat listesi değişince kayıtlı hesap tutarı değişmez', (
      tester,
    ) async {
      final records = await testRecords(tester);
      final catalog = testCatalog();
      final item = (await tester.runAsync(
        () => catalog.addPriceItem(
          name: 'Montaj',
          category: CostKind.labor,
          unit: CostUnit.hour,
          price: tl('300'),
        ),
      ))!;
      await pumpScreen(
        tester,
        const CalculationPage(initialCategoryId: 'ceramic_tile'),
        records: records,
        catalog: catalog,
      );
      await quickPiece(tester, '100');
      await tapKey(tester, 'add_cost_item');
      await tapInSheet(tester, 'add_price_${item.id}');
      await tester.tap(find.byKey(const ValueKey('cost_save')));
      await tester.pumpAndSettle();
      await openSave(tester);
      await setName(tester, 'Montajlı');
      await confirmSave(tester);
      final id = records.calculations.single.id;
      expect(
        records.calculations.single.grandTotal,
        tl('480'),
      ); // (100+300)×1,2

      await tester.runAsync(
        () => catalog.updatePriceItem(item.id, price: tl('900')),
      );
      await pumpScreen(
        tester,
        CalculationDetailPage(id: id),
        records: records,
        catalog: catalog,
      );
      await reveal(tester, 'grand_total');
      expect(inKey('grand_total', '₺480,00'), findsOneWidget);
      expect(records.calculationById(id)!.grandTotal, tl('480'));

      // Düzenlemek için açınca da kayıttaki fiyat yüklenir (₺300).
      await tapKey(tester, 'detail_edit', up: true);
      expect(bar('₺480,00'), findsOneWidget);
    });

    testWidgets('uygulama yeniden açılınca kayıtlar geri gelir', (
      tester,
    ) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('ustametre_restart_'),
      ))!;
      addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
      final path = '${dir.path}/ustametre.db';

      final first = await testRecords(tester, path: path);
      await tester.runAsync(() async {
        await first.saveCustomer(name: 'Kalıcı Müşteri');
        await first.saveProject(name: 'Kalıcı Proje');
      });
      await pumpScreen(
        tester,
        const CalculationPage(initialCategoryId: 'ceramic_tile'),
        records: first,
      );
      await quickPiece(tester, '100');
      await openSave(tester);
      await setName(tester, 'Kalıcı Hesap');
      await confirmSave(tester);

      // "Yeniden başlatma": aynı dosyadan yeni depo ve yeni uygulama.
      final second = await testRecords(tester, path: path);
      expect(identical(first, second), isFalse);
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UstaMetreApp(records: second));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('1 hesap · 1 proje · 1 müşteri'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('home_history')));
      await tester.pumpAndSettle();
      expect(find.text('Kalıcı Hesap'), findsOneWidget);
    });

    testWidgets('kayıt deposu açılamazsa ekranlar açıklama gösterir', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const HistoryPage(),
        records: RecordsController.unavailable('disk hatası'),
      );
      expect(find.byKey(const ValueKey('records_unavailable')), findsOneWidget);
      expect(find.textContaining('silinmedi'), findsOneWidget);
    });
  });
}
