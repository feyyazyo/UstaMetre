// Gerçek telefonda bildirilen iki soruna yönelik testler:
// 1) Mermer: ikinci ve sonraki parçalar eklenemiyor / erişilemiyor.
// 2) PVC: kapı, pencere, balkon kapısı seçenekleri görünmüyor.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustametre/app/app.dart';
import 'package:ustametre/core/constants/app_strings.dart';
import 'package:ustametre/features/calculations/calculation_page.dart';
import 'package:ustametre/features/calculations/marble/marble_project_page.dart';
import 'package:ustametre/features/calculations/pvc/pvc_project_page.dart';

import '../helpers.dart';

Future<void> addPiece(
  WidgetTester tester, {
  required String length,
  required String depth,
  String? quantity,
  List<String> edges = const [],
  bool useTopSave = false,
}) async {
  await tapKey(tester, 'add_piece');
  await tester.enterText(find.byKey(const ValueKey('piece_length')), length);
  await tester.enterText(find.byKey(const ValueKey('piece_depth')), depth);
  if (quantity != null) {
    await tester.enterText(
      find.byKey(const ValueKey('piece_quantity')),
      quantity,
    );
  }
  await tester.pump();
  for (final e in edges) {
    await tapKey(tester, 'edge_$e');
  }
  if (useTopSave) {
    await tester.tap(find.byKey(const ValueKey('piece_save_top')));
    await tester.pumpAndSettle();
  } else {
    await tapKey(tester, 'piece_save');
  }
}

Future<void> fill(WidgetTester tester, String key, String text) async {
  final f = await reveal(tester, key);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> addJoinery(
  WidgetTester tester,
  String type,
  String width,
  String height,
) async {
  await tapKey(tester, 'add_$type');
  await fill(tester, 'j_width', width);
  await fill(tester, 'j_height', height);
  await tester.tap(find.byKey(const ValueKey('j_save_top')));
  await tester.pumpAndSettle();
}

void main() {
  group('Giriş noktası: hızlı hesaptan proje ekranlarına', () {
    testWidgets('Ana sayfa → Yeni Hesaplama → çok parçalı tezgâh bağlantısı '
        'ekranın üstünde görünür', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const UstaMetreApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.newCalculation));
      await tester.pumpAndSettle();
      final banner = find.byKey(const ValueKey('open_project'));
      expect(banner.hitTestable(), findsOneWidget); // kaydırmadan görünür
      expect(find.text('Çok parçalı tezgâh projesi'), findsOneWidget);
      expect(find.text('Tek parça tezgâh'), findsOneWidget);

      await tester.tap(banner);
      await tester.pumpAndSettle();
      expect(find.byType(MarbleProjectPage), findsOneWidget);
    });

    testWidgets(
      'hızlı hesapta PVC seçilince doğrama projesi bağlantısı çıkar',
      (tester) async {
        await pumpScreen(
          tester,
          const CalculationPage(initialCategoryId: 'pvc_joinery'),
        );
        expect(
          find.text('Pencere · Kapı · Balkon kapısı — cam, profil, aksesuar'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('open_project')));
        await tester.pumpAndSettle();
        expect(find.byType(PvcProjectPage), findsOneWidget);
        for (final t in ['window', 'door', 'balconyDoor']) {
          expect(await reveal(tester, 'add_$t'), findsOneWidget);
        }
      },
    );

    testWidgets('özel projesi olmayan kategoride bağlantı yok', (tester) async {
      await pumpScreen(
        tester,
        const CalculationPage(initialCategoryId: 'ceramic_tile'),
      );
      expect(find.byKey(const ValueKey('open_project')), findsNothing);
    });
  });

  group('Mermer: çok parçalı tezgâh', () {
    testWidgets('3 parça bağımsız ölçü ve kenarlarla; düzenle, kopyala, sil, '
        'geri al; toplamlar doğru', (tester) async {
      await pumpScreen(tester, const MarbleProjectPage());
      expect(find.text('İlk parçayı ekle'), findsOneWidget);

      await addPiece(
        tester,
        length: '250',
        depth: '62',
        edges: ['sakal_front'],
      );
      expect(find.text('Yeni parça ekle (2. parça)'), findsOneWidget);
      await addPiece(
        tester,
        length: '120',
        depth: '62',
        edges: ['pah_front', 'pah_left'],
      );
      expect(find.text('Yeni parça ekle (3. parça)'), findsOneWidget);
      await addPiece(
        tester,
        length: '80',
        depth: '40',
        quantity: '2',
        edges: ['rodaj_front'],
        useTopSave: true,
      );
      expect(await revealText(tester, 'Tezgâh parçaları (3)'), findsOneWidget);
      // Her kart kendi alanını gösterir.
      expect(inKey('piece_t1', '1,55 m²'), findsOneWidget);
      expect(inKey('piece_t2', '0,744 m²'), findsOneWidget);
      expect(inKey('piece_t3', '0,64 m²'), findsOneWidget);
      expect(
        inKey('piece_t3', '80 × 40 cm × 2 adet\nRodaj: Ön'),
        findsOneWidget,
      );

      await enterKey(tester, 'field_materialPrice', '1.000');
      await enterKey(tester, 'field_labor', '100');
      await enterKey(tester, 'field_edge_sakal', '200');
      await enterKey(tester, 'field_edge_pah', '100');
      await enterKey(tester, 'field_edge_rodaj', '50');
      // Malzeme 2,934 m² × 1.000 = 2.934; işçilik 5,3 mtül × 100 = 530;
      // sakal 2,5 × 200 = 500; pah 1,82 × 100 = 182; rodaj 1,6 × 50 = 80
      // → 4.226 + %20 KDV = 5.071,20
      expect(bar('₺5.071,20'), findsOneWidget);
      await reveal(tester, 'kind_total_material');
      expect(inKey('kind_total_material', '₺2.934,00'), findsOneWidget);
      expect(inKey('kind_total_labor', '₺1.292,00'), findsOneWidget);

      // 2. parçayı düzenle: yalnızca o parça değişir (derinlik 62 → 70).
      await tapKey(tester, 'piece_t2_edit', up: true);
      await tester.enterText(find.byKey(const ValueKey('piece_depth')), '70');
      // Bilinçli olarak pump yok: kaydetme anında son değer okunmalı.
      await tester.tap(find.byKey(const ValueKey('piece_save_top')));
      await tester.pumpAndSettle();
      await reveal(tester, 'piece_t1', up: true);
      expect(inKey('piece_t1', '1,55 m²'), findsOneWidget);
      await reveal(tester, 'piece_t2');
      expect(inKey('piece_t2', '0,84 m²'), findsOneWidget);
      expect(bar('₺5.196,00'), findsOneWidget); // +96 malzeme, +8 pah

      // 1. parçayı kopyala → 4 parça
      await tapKey(tester, 'piece_t1_copy', up: true);
      expect(await revealText(tester, 'Tezgâh parçaları (4)'), findsOneWidget);
      expect(bar('₺7.956,00'), findsOneWidget); // +1.550 +250 +500

      // 3. parçayı sil, sonra geri al
      await tapKey(tester, 'piece_t3_delete');
      expect(await revealText(tester, 'Tezgâh parçaları (3)'), findsOneWidget);
      expect(bar('₺6.900,00'), findsOneWidget); // −640 −160 −80
      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(await revealText(tester, 'Tezgâh parçaları (4)'), findsOneWidget);
      expect(bar('₺7.956,00'), findsOneWidget);
    });

    testWidgets('klavye açıkken (kısa ekran) üstteki Kaydet erişilebilir', (
      tester,
    ) async {
      await pumpScreen(tester, const MarbleProjectPage());
      // Klavye ekranın yarısını kaplıyormuş gibi: 360 × 400 dp
      tester.view.physicalSize = const Size(1080, 1200);
      await tester.pumpAndSettle();
      await tapKey(tester, 'add_piece');
      await tester.enterText(find.byKey(const ValueKey('piece_length')), '100');
      await tester.enterText(find.byKey(const ValueKey('piece_depth')), '60');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('piece_save')).hitTestable(),
        findsNothing,
      ); // alttaki buton görünmüyor
      final top = find.byKey(const ValueKey('piece_save_top'));
      expect(top.hitTestable(), findsOneWidget); // üstteki görünüyor
      await tester.tap(top);
      await tester.pumpAndSettle();
      expect(await revealText(tester, 'Tezgâh parçaları (1)'), findsOneWidget);
    });

    testWidgets('kaydetmeden X: onay sorulur, veri kaybı uyarılır', (
      tester,
    ) async {
      await pumpScreen(tester, const MarbleProjectPage());
      await tapKey(tester, 'add_piece');
      await tester.enterText(find.byKey(const ValueKey('piece_length')), '100');
      await tester.pump();

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Kaydedilmedi'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discard_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('piece_length')), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discard_confirm')));
      await tester.pumpAndSettle();
      expect(await revealText(tester, 'Tezgâh parçaları (0)'), findsOneWidget);
    });

    testWidgets('değişiklik yoksa X onay sormadan kapatır', (tester) async {
      await pumpScreen(tester, const MarbleProjectPage());
      await tapKey(tester, 'add_piece');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Kaydedilmedi'), findsNothing);
      expect(find.byType(MarbleProjectPage), findsOneWidget);
    });
  });

  group('PVC: pencere, kapı, balkon kapısı', () {
    testWidgets('üç tür ayrı butonla eklenir; tür kartta ve sonuçta görünür', (
      tester,
    ) async {
      await pumpScreen(tester, const PvcProjectPage());
      expect(find.text('Pencere ekle'), findsOneWidget);
      expect(find.text('Kapı ekle'), findsOneWidget);
      expect(find.text('Balkon kapısı ekle'), findsOneWidget);

      await addJoinery(tester, 'window', '120', '150');
      await addJoinery(tester, 'door', '90', '210');
      await addJoinery(tester, 'balconyDoor', '90', '220');

      expect(await revealText(tester, 'Doğrama kalemleri (3)'), findsOneWidget);
      expect(inKey('joinery_t1', 'Pencere 1'), findsOneWidget);
      expect(inKey('joinery_t2', 'Kapı 1'), findsOneWidget);
      expect(inKey('joinery_t3', 'Balkon kapısı 1'), findsOneWidget);

      await reveal(tester, 'result_card');
      expect(inKey('result_card', 'Pencere (1 adet)'), findsOneWidget);
      expect(inKey('result_card', 'Kapı (1 adet)'), findsOneWidget);
      expect(inKey('result_card', 'Balkon kapısı (1 adet)'), findsOneWidget);
      expect(inKey('result_card', '5,67 m²'), findsOneWidget); // toplam
    });

    testWidgets('editörde tür seçimi açık; tür değişince etiket ve sonuç '
        'güncellenir', (tester) async {
      await pumpScreen(tester, const PvcProjectPage());
      await addJoinery(tester, 'window', '120', '150');
      await addJoinery(tester, 'door', '90', '210');

      // Kapı 1'i aç: üç tür kartı ve başlıkta seçili tür görünür.
      await tapKey(tester, 'joinery_t2_edit', up: true);
      expect(find.widgetWithText(AppBar, 'Kapı'), findsOneWidget);
      for (final t in ['window', 'door', 'balconyDoor']) {
        expect(find.byKey(ValueKey('j_type_$t')).hitTestable(), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('j_type_window')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Pencere'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('j_save_top')));
      await tester.pumpAndSettle();

      expect(inKey('joinery_t2', 'Pencere 2'), findsOneWidget);
      await reveal(tester, 'result_card');
      expect(inKey('result_card', 'Pencere (2 adet)'), findsOneWidget);
      expect(inKey('result_card', 'Kapı (1 adet)'), findsNothing);
      expect(inKey('result_card', '3,69 m²'), findsWidgets); // 1,8 + 1,89
    });

    testWidgets('dar ekranda (320 dp) tür etiketleri taşmaz', (tester) async {
      await pumpScreen(tester, const PvcProjectPage());
      tester.view.physicalSize = const Size(960, 2000); // 320 dp genişlik
      await tester.pumpAndSettle();
      await tapKey(tester, 'add_balconyDoor');
      expect(tester.takeException(), isNull);
      expect(find.text('Balkon kapısı'), findsWidgets);
    });
  });
}
