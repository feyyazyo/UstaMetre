import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustametre/features/calculations/marble/marble_project_page.dart';

import '../helpers.dart';

Future<void> addPiece(
  WidgetTester tester, {
  required String name,
  required String length,
  required String depth,
  List<String> edges = const [],
}) async {
  await tapKey(tester, 'add_piece');
  await tester.enterText(find.byKey(const ValueKey('piece_name')), name);
  await tester.enterText(find.byKey(const ValueKey('piece_length')), length);
  await tester.enterText(find.byKey(const ValueKey('piece_depth')), depth);
  await tester.pump();
  for (final e in edges) {
    await tapKey(tester, 'edge_$e');
  }
  await tapKey(tester, 'piece_save');
}

void main() {
  testWidgets('çok parçalı tezgâh, kenar işlemleri, kopyala ve sil', (
    tester,
  ) async {
    await pumpScreen(tester, const MarbleProjectPage());
    expect(bar('En az bir tezgâh parçası ekleyin.'), findsOneWidget);

    await addPiece(
      tester,
      name: 'Ana tezgâh',
      length: '250',
      depth: '62',
      edges: ['sakal_front', 'pah_front', 'pah_left'],
    );
    await addPiece(
      tester,
      name: 'Yan tezgâh',
      length: '120',
      depth: '62',
      edges: ['sakal_front', 'sakal_right'],
    );
    expect(bar('2,294 m²'), findsNothing); // fire yokken ana değer uzunluk
    expect(bar('3,7 mtül'), findsOneWidget);

    await enterKey(tester, 'field_waste', '10');
    await enterKey(tester, 'field_materialPrice', '3.200');
    await enterKey(tester, 'field_labor', '450');
    await enterKey(tester, 'field_edge_sakal', '350');
    await enterKey(tester, 'field_edge_pah', '120');

    // 8.074,88 + 1.665 + 1.512 + 374,40 = 11.626,28 + %20 KDV
    expect(bar('₺13.951,54'), findsOneWidget);

    await reveal(tester, 'how_calculated');
    expect(
      find.text(
        'Sakal = Ana tezgâh ön (2,5 m) + Yan tezgâh ön (1,2 m) + '
        'Yan tezgâh sağ (0,62 m) = 4,32 mtül',
      ),
      findsOneWidget,
    );

    // Yan tezgâhı (t2) kopyala: alan, uzunluk ve sakal artar.
    await tapKey(tester, 'piece_menu_t2', up: true);
    await tester.tap(find.text('Kopyala').last);
    await tester.pumpAndSettle();
    expect(find.text('Yan tezgâh (kopya)'), findsOneWidget);
    expect(bar('₺18.506,59'), findsOneWidget);

    // Kopyayı (t3) sil → önceki toplam
    await tapKey(tester, 'piece_menu_t3');
    await tester.tap(find.text('Sil').last);
    await tester.pumpAndSettle();
    expect(find.text('Yan tezgâh (kopya)'), findsNothing);
    expect(bar('₺13.951,54'), findsOneWidget);
  });

  testWidgets('evye ve nakliye ek kalemleri toplamlara eklenir', (
    tester,
  ) async {
    await pumpScreen(tester, const MarbleProjectPage());
    await addPiece(tester, name: 'Tezgâh', length: '200', depth: '60');
    await enterKey(tester, 'field_materialPrice', '1.000');
    expect(bar('₺1.440,00'), findsOneWidget); // 1,2 m² × 1000 × 1,2

    for (final (name, price) in [('Evye bedeli', '2400'), ('Nakliye', '800')]) {
      await tapKey(tester, 'add_cost_item');
      await tapInSheet(tester, 'add_template_$name');
      await tester.enterText(find.byKey(const ValueKey('cost_price')), price);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cost_save')));
      await tester.pumpAndSettle();
    }
    // (1.200 + 2.400 + 800) × 1,2
    expect(bar('₺5.280,00'), findsOneWidget);
    await reveal(tester, 'kind_total_accessory');
    expect(inKey('kind_total_accessory', '₺2.400,00'), findsOneWidget);
    expect(inKey('kind_total_shipping', '₺800,00'), findsOneWidget);
  });

  testWidgets('parça ölçüsü olmadan kaydedilemez', (tester) async {
    await pumpScreen(tester, const MarbleProjectPage());
    await tapKey(tester, 'add_piece');
    await tapKey(tester, 'piece_save');
    expect(find.byKey(const ValueKey('piece_error')), findsOneWidget);
    await reveal(tester, 'piece_length', up: true);
    expect(find.text('Bu alan gerekli'), findsNWidgets(2));
    expect(find.text('Tezgâh parçası'), findsOneWidget); // editör açık kaldı
  });
}
