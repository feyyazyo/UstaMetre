import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustametre/core/theme/app_theme.dart';
import 'package:ustametre/data/catalog_controller.dart';
import 'package:ustametre/data/catalog_scope.dart';
import 'package:ustametre/data/key_value_store.dart';
import 'package:ustametre/engine/ids.dart';

/// Testler için bellek içi katalog (öngörülebilir kimliklerle).
CatalogController testCatalog() => CatalogController(
  store: MemoryStore(),
  ids: SequentialIdGenerator('t'),
  clock: () => DateTime.utc(2026, 11, 1),
);

/// Bir sayfayı tema ve katalogla birlikte telefon boyutunda açar.
Future<CatalogController> pumpScreen(
  WidgetTester tester,
  Widget home, {
  CatalogController? catalog,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final c = catalog ?? testCatalog();
  await tester.pumpWidget(
    CatalogScope(
      controller: c,
      child: MaterialApp(theme: AppTheme.dark(), home: home),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Finder get firstScrollable => find.byType(Scrollable).first;

/// Tembel kurulan listede öğe görünene kadar kaydırır. Öğe ağaçta yoksa
/// önce [up] yönünde, bulunamazsa ters yönde arar.
Future<Finder> reveal(
  WidgetTester tester,
  String key, {
  bool up = false,
  Finder? scrollable,
}) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    Future<void> scroll(double delta) => tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: scrollable ?? firstScrollable,
      maxScrolls: 60,
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

Future<void> enterKey(WidgetTester tester, String key, String text) async {
  final finder = await reveal(tester, key);
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> tapKey(WidgetTester tester, String key, {bool up = false}) async {
  final finder = await reveal(tester, key, up: up);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder inKey(String key, String text) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

/// Ekranın altındaki sabit özet çubuğunda metin.
Finder bar(String text) => inKey('live_total', text);

/// Alt paneldeki (DraggableScrollableSheet) öğeye kaydırıp dokunur.
Future<void> tapInSheet(WidgetTester tester, String key) async {
  final tile = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    tile,
    100,
    scrollable: find
        .descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}
