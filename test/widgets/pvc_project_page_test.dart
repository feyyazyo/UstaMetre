import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustametre/engine/calculators/pvc_joinery_calculator.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/features/calculations/pvc/pvc_project_page.dart';

import '../helpers.dart';

Future<void> fill(WidgetTester tester, String key, String text) async {
  final f = await reveal(tester, key);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> chooseDropdown(
  WidgetTester tester,
  String key,
  String option,
) async {
  await tapKey(tester, key);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reçete oluştur, doğramaya uygula, uyarıları gör', (
    tester,
  ) async {
    final catalog = await pumpScreen(tester, const PvcProjectPage());
    expect(bar('En az bir doğrama kalemi ekleyin.'), findsOneWidget);

    // Profil reçetesi oluştur: kasa (başlangıç bileşeni) + kanat
    await tester.tap(find.byKey(const ValueKey('open_recipes')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'add_recipe');
    await fill(tester, 'recipe_name', 'Tek kanat');
    await fill(tester, 'component_0_price', '180');
    await tapKey(tester, 'add_component');
    await fill(tester, 'component_1_name', 'Kanat');
    await fill(tester, 'component_1_wf', '2');
    await fill(tester, 'component_1_hf', '2');
    await fill(tester, 'component_1_offset', '-0,2');
    await fill(tester, 'component_1_price', '210');
    await tapKey(tester, 'recipe_save');
    expect(catalog.recipes.single.name, 'Tek kanat');
    expect(catalog.recipes.single.verified, isFalse);
    expect(
      find.text('Doğrulanmamış (tahmini)', findRichText: true),
      findsNothing,
    ); // alt satırda birleşik metin
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Doğrama ekle
    await tapKey(tester, 'add_joinery');
    await fill(tester, 'j_width', '120');
    await fill(tester, 'j_height', '150');
    await fill(tester, 'j_quantity', '2');
    await fill(tester, 'j_glassType', 'Isıcam 4+16+4');
    await fill(tester, 'j_glassPrice', '950');
    await chooseDropdown(tester, 'j_profileMode', 'Profil reçetesi');
    await fill(tester, 'j_accessory', '1.250');
    await tapKey(tester, 'j_flyScreen');
    await fill(tester, 'j_flyScreenPrice', '400');
    await tapKey(tester, 'j_save');

    // Cam 3,6 m² × 950 = 3.420; kasa 10,8 m × 180 = 1.944;
    // kanat 10,4 m × 210 = 2.184; aksesuar 2.500; sineklik 800 → 10.848
    expect(bar('₺13.017,60'), findsOneWidget);
    await reveal(tester, 'warnings');
    expect(find.textContaining('dış ölçüden alındı'), findsOneWidget);
    expect(find.textContaining('doğrulanmamış'), findsOneWidget);

    // Ölçülen cam alanını gir → cam kesinleşir, uyarı kalkar
    await tapKey(tester, 'joinery_t2', up: true);
    await fill(tester, 'j_glassArea', '1,45');
    await tapKey(tester, 'j_save');
    expect(bar('₺12.219,60'), findsOneWidget); // cam 2,9 m² × 950 = 2.755
    await reveal(tester, 'warnings');
    expect(find.textContaining('dış ölçüden alındı'), findsNothing);

    // Reçete doğrulandı olarak işaretlenince tahmini uyarısı kalkar
    await catalog.saveRecipe(catalog.recipes.single.copyWith(verified: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('warnings')), findsNothing);
  });

  testWidgets('manuel profil, kopyala, sil', (tester) async {
    await pumpScreen(tester, const PvcProjectPage());
    await tapKey(tester, 'add_joinery');
    await tapKey(tester, 'j_type_door');
    await fill(tester, 'j_width', '90');
    await fill(tester, 'j_height', '210');
    await chooseDropdown(tester, 'j_profileMode', 'Manuel metraj');
    await fill(tester, 'j_profileMeters', '6');
    await fill(tester, 'j_profilePrice', '200');
    await tapKey(tester, 'j_save');
    expect(find.text('Kapı 1'), findsOneWidget);
    expect(bar('₺1.440,00'), findsOneWidget); // 6 m × 200 × 1,2

    await enterKey(tester, 'field_profileWaste', '10');
    expect(bar('₺1.584,00'), findsOneWidget);

    await tapKey(tester, 'joinery_menu_t1', up: true);
    await tester.tap(find.text('Kopyala').last);
    await tester.pumpAndSettle();
    expect(bar('₺3.168,00'), findsOneWidget);

    await tapKey(tester, 'joinery_menu_t2', up: true);
    await tester.tap(find.text('Sil').last);
    await tester.pumpAndSettle();
    expect(bar('₺1.584,00'), findsOneWidget);
  });

  testWidgets('boş ölçüyle doğrama kaydedilemez', (tester) async {
    await pumpScreen(tester, const PvcProjectPage());
    await tapKey(tester, 'add_joinery');
    await tapKey(tester, 'j_save');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('j_error'))).data,
      'Kaydedilemedi: En, Boy alanlarını kontrol edin.',
    );
    await reveal(tester, 'j_width', up: true);
    expect(find.text('Bu alan gerekli'), findsWidgets);
  });

  testWidgets('reçetede adı boş bileşen kaydedilmez', (tester) async {
    final catalog = await pumpScreen(tester, const PvcProjectPage());
    await tester.tap(find.byKey(const ValueKey('open_recipes')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'add_recipe');
    await fill(tester, 'component_0_price', '180');
    await tapKey(tester, 'add_component');
    await tapKey(tester, 'recipe_save');
    expect(find.byKey(const ValueKey('recipe_error')), findsOneWidget);
    expect(catalog.recipes, isEmpty);
  });

  test('reçete bileşeni formül metni', () {
    final c = ProfileComponent(
      name: 'Çıta',
      role: ProfileRole.glazingBead,
      widthFactor: Decimal.fromInt(4),
      heightFactor: Decimal.zero,
      offsetMeters: Decimal.parse('-0.12'),
      pricePerMeter: Money.zero,
    );
    expect(c.formula, '4 × En − 0,12 m');
  });
}
