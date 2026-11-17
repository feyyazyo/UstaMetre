import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/data/catalog_controller.dart';
import 'package:ustametre/data/key_value_store.dart';
import 'package:ustametre/engine/costing/cost_item.dart';
import 'package:ustametre/engine/ids.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/engine/pricing.dart';

void main() {
  Money tl(String s) => Money.fromDecimal(Decimal.parse(s));

  var now = DateTime.utc(2026, 1, 1);
  Future<CatalogController> open(MemoryStore store) => CatalogController.load(
    store,
    ids: SequentialIdGenerator('k'),
    clock: () => now,
  );

  test('fiyat listesi kaydedilir ve yeniden açılınca geri gelir', () async {
    final store = MemoryStore();
    final c = await open(store);
    final item = await c.addPriceItem(
      name: 'Granit plaka',
      category: CostKind.material,
      unit: CostUnit.squareMeter,
      price: tl('3200'),
    );
    now = DateTime.utc(2026, 6, 1);
    await c.updatePriceItem(item.id, price: tl('3500'));

    final reopened = await open(store);
    final restored = reopened.priceList.byId(item.id)!;
    expect(restored.price, tl('3500'));
    expect(restored.history, hasLength(2));
    expect(restored.pointAt(DateTime.utc(2026, 3, 1))!.price, tl('3200'));
  });

  test('hesaplamadaki kalem fiyat listesine kaydedilebilir', () async {
    final c = await open(MemoryStore());
    final saved = await c.saveCostItemToList(
      CostItem(
        id: 'x',
        name: 'Evye montajı',
        category: CostKind.labor,
        quantity: Decimal.one,
        unit: CostUnit.piece,
        unitPrice: tl('750'),
      ),
    );
    expect(saved.userDefined, isTrue);
    expect(c.priceList.byId(saved.id)!.price, tl('750'));
  });

  test('ad değişikliği ve silme kaydedilir', () async {
    final store = MemoryStore();
    final c = await open(store);
    final item = await c.addPriceItem(
      name: 'Nakliye',
      category: CostKind.shipping,
      unit: CostUnit.service,
      price: tl('800'),
    );
    await c.updatePriceItem(item.id, name: 'Şehir içi nakliye');
    expect(
      (await open(store)).priceList.byId(item.id)!.name,
      'Şehir içi nakliye',
    );
    await c.removePriceItem(item.id);
    expect((await open(store)).priceList.items, isEmpty);
  });

  test('profil reçeteleri kaydedilir', () async {
    final store = MemoryStore();
    final c = await open(store);
    final recipe = c.newRecipe().copyWith(name: 'Tek kanat');
    await c.saveRecipe(recipe);
    await c.saveRecipe(recipe.copyWith(verified: true));
    final reopened = await open(store);
    expect(reopened.recipes.single.name, 'Tek kanat');
    expect(reopened.recipes.single.verified, isTrue);
    await reopened.deleteRecipe(recipe.id);
    expect((await open(store)).recipes, isEmpty);
  });

  test('bozuk kayıt yedeklenir, uygulama boş listeyle açılır', () async {
    final store = MemoryStore({CatalogController.priceListKey: '{bozuk'});
    final c = await open(store);
    expect(c.priceList.items, isEmpty);
    expect(
      store
          .data['${CatalogController.corruptPrefix}${CatalogController.priceListKey}'],
      '{bozuk',
    );
  });

  test('kayıt biçimi sürüm bilgisi içerir', () async {
    final store = MemoryStore();
    final c = await open(store);
    await c.addPriceItem(
      name: 'Pah',
      category: CostKind.labor,
      unit: CostUnit.linearMeter,
      price: tl('120'),
    );
    final json = jsonDecode(store.data[CatalogController.priceListKey]!) as Map;
    expect(json['version'], 1);
  });
}
