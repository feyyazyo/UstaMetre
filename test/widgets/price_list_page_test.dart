import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustametre/data/catalog_controller.dart';
import 'package:ustametre/data/key_value_store.dart';
import 'package:ustametre/engine/costing/cost_item.dart';
import 'package:ustametre/engine/ids.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/engine/pricing.dart';
import 'package:ustametre/features/calculations/calculation_page.dart';
import 'package:ustametre/features/price_list/price_list_page.dart';

import '../helpers.dart';

void main() {
  Money tl(String s) => Money.fromDecimal(Decimal.parse(s));

  testWidgets('fiyat ekle, değiştir (geçmiş), sil', (tester) async {
    var now = DateTime(2026, 1, 15);
    final catalog = CatalogController(
      store: MemoryStore(),
      ids: SequentialIdGenerator('p'),
      clock: () => now,
    );
    await pumpScreen(tester, const PriceListPage(), catalog: catalog);
    expect(find.byKey(const ValueKey('price_list_empty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add_price_item')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('price_name')),
      'Granit plaka',
    );
    await tapKey(tester, 'price_unit');
    await tester.tap(find.text('Metrekare').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('price_value')), '3.200');
    await tapKey(tester, 'price_save');

    expect(find.text('Granit plaka'), findsOneWidget);
    expect(find.text('₺3.200,00/m²'), findsOneWidget);
    expect(find.textContaining('1 fiyat kaydı'), findsOneWidget);

    // Fiyat değişikliği geçmişe eklenir
    now = DateTime(2026, 11, 1);
    await tester.tap(find.byKey(const ValueKey('price_item_p1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('price_value')), '3.500');
    await tapKey(tester, 'price_save');
    expect(find.text('₺3.500,00/m²'), findsOneWidget);
    expect(find.textContaining('2 fiyat kaydı'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('price_item_p1')));
    await tester.pumpAndSettle();
    expect(find.text('Fiyat geçmişi'), findsOneWidget);
    expect(find.text('15.01.2026'), findsOneWidget);
    expect(find.text('01.11.2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete_price_item')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('price_list_empty')), findsOneWidget);
  });

  testWidgets('boş ad ve geçersiz fiyat reddedilir', (tester) async {
    await pumpScreen(tester, const PriceListPage());
    await tester.tap(find.byKey(const ValueKey('add_price_item')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('price_value')), '100');
    await tapKey(tester, 'price_save');
    expect(find.text('Kalem adı boş olamaz.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('price_name')), 'Pah');
    await tester.enterText(find.byKey(const ValueKey('price_value')), '1,2,3');
    await tapKey(tester, 'price_save');
    expect(find.text('Geçerli bir sayı girin (ör. 1.250,75)'), findsOneWidget);
  });

  testWidgets(
    'listeden eklenen kalem, liste fiyatı sonradan değişse de korunur',
    (tester) async {
      final catalog = testCatalog();
      final item = await catalog.addPriceItem(
        name: 'Montaj',
        category: CostKind.labor,
        unit: CostUnit.hour,
        price: tl('300'),
      );
      await pumpScreen(
        tester,
        const CalculationPage(initialCategoryId: 'ceramic_tile'),
        catalog: catalog,
      );
      await tapKey(tester, 'mode_piece');
      await tapKey(tester, 'add_cost_item');
      await tapInSheet(tester, 'add_price_${item.id}');
      await tester.tap(find.byKey(const ValueKey('cost_save')));
      await tester.pumpAndSettle();
      expect(bar('₺360,00'), findsOneWidget);

      await catalog.updatePriceItem(item.id, price: tl('450'));
      await tester.pumpAndSettle();
      expect(catalog.priceList.byId(item.id)!.price, tl('450'));
      expect(bar('₺360,00'), findsOneWidget); // eski hesap bozulmadı
    },
  );
}
