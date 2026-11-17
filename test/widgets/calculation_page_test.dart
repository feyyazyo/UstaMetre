import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustametre/features/calculations/calculation_page.dart';

import '../helpers.dart' hide reveal, inKey, bar;

Future<void> pumpPage(WidgetTester tester, {String? categoryId}) =>
    pumpScreen(tester, CalculationPage(initialCategoryId: categoryId));

Finder get pageList => find
    .descendant(
      of: find.byType(CalculationPage),
      matching: find.byType(Scrollable),
    )
    .first;

/// Tembel kurulan listede öğe görünene kadar kaydırır. Öğe ağaçta yoksa
/// önce [up] yönünde, bulunamazsa ters yönde arar.
Future<Finder> reveal(
  WidgetTester tester,
  String key, {
  bool up = false,
}) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    Future<void> scroll(double delta) => tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: pageList,
      maxScrolls: 40,
    );
    try {
      await scroll(up ? -150 : 150);
    } on StateError {
      await scroll(up ? 150 : -150);
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  return finder;
}

Future<void> enter(WidgetTester tester, String field, String text) async {
  final finder = await reveal(tester, 'field_$field');
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> tapTop(WidgetTester tester, String key) async {
  final finder = await reveal(tester, key, up: true);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder inKey(String key, String text) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

/// Ekranın altındaki sabit özet çubuğu.
Finder bar(String text) => inKey('live_total', text);

/// Sonuç kartında metin arar (kart görünür olana kadar kaydırır).
Future<Finder> inResult(WidgetTester tester, String text) async {
  await reveal(tester, 'result_card');
  return inKey('result_card', text);
}

void main() {
  testWidgets('mermer tezgâh: sonuçlar girişle anlık güncellenir', (
    tester,
  ) async {
    await pumpPage(tester, categoryId: 'marble_granite');
    expect(bar('Uzunluk girin.'), findsOneWidget);

    await enter(tester, 'length', '250');
    await enter(tester, 'width', '62');
    expect(await inResult(tester, '1,55 m²'), findsOneWidget);
    expect(inKey('result_card', '2,5 mtül'), findsOneWidget);
    expect(bar('2,5 mtül'), findsOneWidget);

    await enter(tester, 'waste', '10');
    await enter(tester, 'materialPrice', '3.200');
    await enter(tester, 'laborPrice', '450');

    // Sabit çubuk kaydırmadan genel toplamı gösterir.
    expect(bar('₺7.897,20'), findsOneWidget);

    expect(await inResult(tester, '1,705 m²'), findsOneWidget);
    await reveal(tester, 'grand_total');
    expect(inKey('subtotal', '₺6.581,00'), findsOneWidget);
    expect(inKey('vat', '₺1.316,20'), findsOneWidget);
    expect(inKey('grand_total', '₺7.897,20'), findsOneWidget);
    expect(inKey('result_card', 'Malzeme toplamı'), findsOneWidget);
    expect(inKey('result_card', 'İşçilik toplamı'), findsOneWidget);

    // Nasıl hesaplandı?
    await reveal(tester, 'how_calculated');
    expect(find.text('Nasıl hesaplandı?'), findsOneWidget);
    expect(find.text('Net alan = 2,5 m × 0,62 m = 1,55 m²'), findsOneWidget);
    expect(
      find.text('Genel toplam = ₺6.581,00 + ₺1.316,20 = ₺7.897,20'),
      findsOneWidget,
    );

    // KDV değişince toplam anında değişir.
    await enter(tester, 'vat', '10');
    expect(bar('₺7.239,10'), findsOneWidget);
  });

  testWidgets('birim değişince sonuç yeniden hesaplanır', (tester) async {
    await pumpPage(tester, categoryId: 'marble_granite');
    await enter(tester, 'length', '2500');
    await enter(tester, 'width', '620');
    await enter(tester, 'materialPrice', '100');

    // cm: 25 m × 6,2 m = 155 m² × ₺100 = ₺15.500 + %20 KDV
    expect(bar('₺18.600,00'), findsOneWidget);

    await tapTop(tester, 'unit_millimeter');
    // mm: 2,5 m × 0,62 m = 1,55 m² × ₺100 = ₺155 + %20 KDV
    expect(bar('₺186,00'), findsOneWidget);
    expect(await inResult(tester, '1,55 m²'), findsOneWidget);
  });

  testWidgets('hesap türü değişince ilgili alanlar gösterilir', (tester) async {
    await pumpPage(tester, categoryId: 'marble_granite');

    await tapTop(tester, 'mode_volume');
    expect(await reveal(tester, 'field_height'), findsOneWidget);
    expect(find.byKey(const ValueKey('field_laborPrice')), findsNothing);

    await tapTop(tester, 'mode_piece');
    expect(find.byKey(const ValueKey('field_length')), findsNothing);
    expect(find.byKey(const ValueKey('field_height')), findsNothing);
    expect(find.byKey(const ValueKey('unit_select')), findsNothing);

    await enter(tester, 'quantity', '12');
    await enter(tester, 'unitPrice', '37,5');
    expect(bar('₺540,00'), findsOneWidget);
    await reveal(tester, 'grand_total');
    expect(inKey('subtotal', '₺450,00'), findsOneWidget);
    expect(inKey('vat', '₺90,00'), findsOneWidget);
  });

  testWidgets('geçersiz giriş alan hatası gösterir', (tester) async {
    await pumpPage(tester, categoryId: 'marble_granite');
    await enter(tester, 'length', '1,2,3');
    expect(find.text('Geçerli bir sayı girin (ör. 1.250,75)'), findsOneWidget);
    expect(bar('Hatalı alanları düzeltin.'), findsOneWidget);
  });

  testWidgets('harf girişi engellenir', (tester) async {
    await pumpPage(tester, categoryId: 'marble_granite');
    await enter(tester, 'length', '12a5');
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('field_length')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, '125');
  });

  testWidgets('özel hesabı olmayan kategoride bilgi notu gösterilir', (
    tester,
  ) async {
    await pumpPage(tester, categoryId: 'ceramic_tile');
    expect(find.byKey(const ValueKey('generic_only_note')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode_marbleCountertop')), findsNothing);
    expect(find.byKey(const ValueKey('mode_length')), findsOneWidget);
  });

  testWidgets('kategori menüden değiştirilebilir', (tester) async {
    await pumpPage(tester, categoryId: 'ceramic_tile');
    await tester.tap(find.byKey(const ValueKey('category_select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mermer ve granit').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mode_marbleCountertop')), findsOneWidget);
    expect(find.byKey(const ValueKey('generic_only_note')), findsNothing);
  });

  testWidgets('giriş alanları rahat dokunma yüksekliğinde', (tester) async {
    await pumpPage(tester, categoryId: 'marble_granite');
    final field = await reveal(tester, 'field_length');
    expect(tester.getSize(field).height, greaterThanOrEqualTo(56));
  });
}
