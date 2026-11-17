import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../engine/calculators/pvc_joinery_calculator.dart';
import '../engine/costing/cost_item.dart';
import '../engine/costing/price_list.dart';
import '../engine/ids.dart';
import '../engine/money.dart';
import '../engine/pricing.dart';
import 'key_value_store.dart';

/// Fiyat listesini ve profil reçetelerini tutar, her değişiklikte cihaza
/// kaydeder (offline).
class CatalogController extends ChangeNotifier {
  CatalogController({
    required this._store,
    this._priceList = const PriceList(),
    List<ProfileRecipe> recipes = const [],
    IdGenerator? ids,
    DateTime Function()? clock,
  }) : _recipes = List.unmodifiable(recipes),
       ids = ids ?? TimestampIdGenerator(),
       _clock = clock ?? DateTime.now;

  static const priceListKey = 'price_list.v1';
  static const recipesKey = 'profile_recipes.v1';

  /// Okunamayan kayıtlar silinmez, bu öneklerle yedeklenir.
  static const corruptPrefix = 'corrupt.';

  final KeyValueStore _store;
  final IdGenerator ids;
  final DateTime Function() _clock;

  PriceList _priceList;
  List<ProfileRecipe> _recipes;

  PriceList get priceList => _priceList;
  List<ProfileRecipe> get recipes => _recipes;

  /// Kayıtlı veriyi yükler. Bozuk kayıt varsa yedeğini alıp boş başlar.
  static Future<CatalogController> load(
    KeyValueStore store, {
    IdGenerator? ids,
    DateTime Function()? clock,
  }) async {
    var priceList = const PriceList();
    var recipes = <ProfileRecipe>[];

    final rawList = await store.read(priceListKey);
    if (rawList != null) {
      try {
        priceList = PriceList.fromJson(
          (jsonDecode(rawList) as Map).cast<String, Object?>(),
        );
      } on Object {
        await store.write('$corruptPrefix$priceListKey', rawList);
      }
    }
    final rawRecipes = await store.read(recipesKey);
    if (rawRecipes != null) {
      try {
        recipes = [
          for (final r in jsonDecode(rawRecipes) as List)
            ProfileRecipe.fromJson((r as Map).cast<String, Object?>()),
        ];
      } on Object {
        await store.write('$corruptPrefix$recipesKey', rawRecipes);
      }
    }
    return CatalogController(
      store: store,
      priceList: priceList,
      recipes: recipes,
      ids: ids,
      clock: clock,
    );
  }

  // ---- Fiyat listesi ----

  Future<PriceListItem> addPriceItem({
    required String name,
    required CostKind category,
    required CostUnit unit,
    required Money price,
    String description = '',
  }) async {
    final item = PriceListItem.create(
      id: ids.next(),
      name: name,
      category: category,
      unit: unit,
      price: price,
      at: _clock(),
      description: description,
    );
    _priceList = _priceList.add(item);
    await _savePriceList();
    return item;
  }

  /// Hesaplamadaki bir kalemi sık kullanılanlar için fiyat listesine kaydeder.
  Future<PriceListItem> saveCostItemToList(CostItem item) => addPriceItem(
    name: item.name,
    category: item.category,
    unit: item.unit,
    price: item.unitPrice,
    description: item.description,
  );

  Future<void> updatePriceItem(
    String id, {
    String? name,
    String? description,
    CostKind? category,
    Money? price,
    CostUnit? unit,
  }) async {
    var item = _priceList.byId(id);
    if (item == null) throw StateError('Kayıt bulunamadı: $id');
    item = item.rename(
      name: name,
      description: description,
      category: category,
    );
    if (price != null || unit != null) {
      item = item.withPrice(price ?? item.price, at: _clock(), unit: unit);
    }
    _priceList = _priceList.replace(item);
    await _savePriceList();
  }

  Future<void> removePriceItem(String id) async {
    _priceList = _priceList.remove(id);
    await _savePriceList();
  }

  // ---- Profil reçeteleri ----

  ProfileRecipe newRecipe() => PvcCatalog.starterRecipe(ids.next());

  Future<void> saveRecipe(ProfileRecipe recipe) async {
    final index = _recipes.indexWhere((r) => r.id == recipe.id);
    _recipes = List.unmodifiable(
      index < 0 ? [..._recipes, recipe] : ([..._recipes]..[index] = recipe),
    );
    await _saveRecipes();
  }

  Future<void> deleteRecipe(String id) async {
    _recipes = List.unmodifiable(_recipes.where((r) => r.id != id));
    await _saveRecipes();
  }

  Future<void> _savePriceList() async {
    notifyListeners();
    await _store.write(priceListKey, jsonEncode(_priceList.toJson()));
  }

  Future<void> _saveRecipes() async {
    notifyListeners();
    await _store.write(
      recipesKey,
      jsonEncode([for (final r in _recipes) r.toJson()]),
    );
  }
}
