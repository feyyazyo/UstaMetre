import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustametre/features/calculations/calculation_page.dart';

import '../helpers.dart';

/// Ek maliyet editöründe kalem doldurup kaydeder.
Future<void> fillCostEditor(
  WidgetTester tester, {
  String? name,
  String? quantity,
  String? price,
}) async {
  if (name != null) {
    await tester.enterText(find.byKey(const ValueKey('cost_name')), name);
  }
  if (quantity != null) {
    await tester.enterText(
      find.byKey(const ValueKey('cost_quantity')),
      quantity,
    );
  }
  if (price != null) {
    await tester.enterText(find.byKey(const ValueKey('cost_price')), price);
  }
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('cost_save')));
  await tester.tap(find.byKey(const ValueKey('cost_save')));
  await tester.pumpAndSettle();
}

Future<void> menu(WidgetTester tester, String itemId, String action) async {
  await tapKey(tester, 'cost_menu_$itemId');
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'ek maliyet ekle, kopyala, düzenle, sil — toplam anında değişir',
    (tester) async {
      await pumpScreen(
        tester,
        const CalculationPage(initialCategoryId: 'ceramic_tile'),
      );
      await tapKey(tester, 'mode_piece');
      await enterKey(tester, 'field_unitPrice', '100');
      expect(bar('₺120,00'), findsOneWidget); // 100 + %20 KDV

      // Ekle: kullanıcıya özel kalem
      await tapKey(tester, 'add_cost_item');
      await tester.tap(find.byKey(const ValueKey('add_blank')));
      await tester.pumpAndSettle();
      await fillCostEditor(tester, name: 'Nakliye', price: '500');
      expect(find.byKey(const ValueKey('cost_item_t1')), findsOneWidget);
      expect(bar('₺720,00'), findsOneWidget); // (100 + 500) × 1,2

      // Kopyala
      await menu(tester, 't1', 'Kopyala');
      expect(find.text('Nakliye (kopya)'), findsOneWidget);
      expect(bar('₺1.320,00'), findsOneWidget);

      // Düzenle (kopyanın fiyatı 250)
      await tapKey(tester, 'cost_item_t2');
      await fillCostEditor(tester, quantity: '2', price: '125,5');
      expect(bar('₺1.021,20'), findsOneWidget); // (100 + 500 + 251) × 1,2

      // Sil
      await menu(tester, 't2', 'Sil');
      expect(find.byKey(const ValueKey('cost_item_t2')), findsNothing);
      expect(bar('₺720,00'), findsOneWidget);
      await reveal(tester, 'extras_total');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('extras_total'))).data,
        'Ek kalemler toplamı: ₺500,00',
      );
    },
  );

  testWidgets('boş kalem adıyla kaydedilemez', (tester) async {
    await pumpScreen(tester, const CalculationPage());
    await tapKey(tester, 'add_cost_item');
    await tester.tap(find.byKey(const ValueKey('add_blank')));
    await tester.pumpAndSettle();
    await fillCostEditor(tester, price: '10');
    expect(find.text('Kalem adı boş olamaz.'), findsOneWidget);
    expect(find.byKey(const ValueKey('cost_save')), findsOneWidget);
  });

  testWidgets('mermer hazır kalemleri sunulur (evye montajı)', (tester) async {
    await pumpScreen(
      tester,
      const CalculationPage(initialCategoryId: 'marble_granite'),
    );
    await tapKey(tester, 'mode_piece');
    await tapKey(tester, 'add_cost_item');
    await tester.tap(find.byKey(const ValueKey('add_template_Evye montajı')));
    await tester.pumpAndSettle();
    expect(find.text('Evye montajı'), findsOneWidget);
    await fillCostEditor(tester, price: '750');
    expect(find.byKey(const ValueKey('cost_item_t1')), findsOneWidget);
    expect(bar('₺900,00'), findsOneWidget);
  });

  testWidgets('fiyat listesine kaydedilen kalem listeden tekrar eklenir', (
    tester,
  ) async {
    final catalog = await pumpScreen(tester, const CalculationPage());
    await tapKey(tester, 'mode_piece');
    await tapKey(tester, 'add_cost_item');
    await tester.tap(find.byKey(const ValueKey('add_blank')));
    await tester.pumpAndSettle();
    await fillCostEditor(tester, name: 'Montaj', price: '300');
    await menu(tester, 't1', 'Fiyat listesine kaydet');
    expect(catalog.priceList.items.single.name, 'Montaj');

    final saved = catalog.priceList.items.single;
    // "Kaydedildi" bildiriminin kapanmasını bekle.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tapKey(tester, 'add_cost_item');
    await tapInSheet(tester, 'add_price_${saved.id}');
    await fillCostEditor(tester, quantity: '2');
    expect(bar('₺1.080,00'), findsOneWidget); // (300 + 600) × 1,2
  });

  testWidgets('indirim ve KDV dahil gösterim', (tester) async {
    await pumpScreen(
      tester,
      const CalculationPage(initialCategoryId: 'ceramic_tile'),
    );
    await tapKey(tester, 'mode_piece');
    await enterKey(tester, 'field_unitPrice', '1.000');

    await tapKey(tester, 'discount_mode');
    await tester.tap(find.text('Yüzde (%)').last);
    await tester.pumpAndSettle();
    await enterKey(tester, 'field_discount', '10');
    expect(bar('₺1.080,00'), findsOneWidget); // 900 × 1,2
    await reveal(tester, 'tax_base');
    expect(inKey('discount', '-₺100,00'), findsOneWidget);
    expect(inKey('tax_base', '₺900,00'), findsOneWidget);

    await enterKey(tester, 'field_discount', '150');
    expect(
      find.text('İndirim oranı %0 ile %100 arasında olmalıdır.'),
      findsOneWidget,
    );
    await enterKey(tester, 'field_discount', '10');

    await enterKey(tester, 'field_vat', '10');
    expect(bar('₺990,00'), findsOneWidget);

    await tapKey(tester, 'vat_display_included');
    await reveal(tester, 'vat_included_note');
    expect(find.text('₺1.100,00'), findsOneWidget); // satır KDV dahil
    expect(inKey('grand_total', '₺990,00'), findsOneWidget);
  });
}
