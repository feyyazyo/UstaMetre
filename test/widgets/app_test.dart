import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustametre/app/app.dart';
import 'package:ustametre/core/constants/app_strings.dart';
import 'package:ustametre/core/theme/app_colors.dart';
import 'package:ustametre/domain/trade_category.dart';
import 'package:ustametre/features/calculations/calculation_page.dart';
import 'package:ustametre/features/calculations/calculations_page.dart';
import 'package:ustametre/features/calculations/category_hub_page.dart';
import 'package:ustametre/features/calculations/marble/marble_project_page.dart';
import 'package:ustametre/features/calculations/pvc/pvc_project_page.dart';
import 'package:ustametre/features/calculations/pvc/recipe_pages.dart';
import 'package:ustametre/features/price_list/price_list_page.dart';
import 'package:ustametre/features/customers/customers_page.dart';
import 'package:ustametre/features/projects/projects_page.dart';
import 'package:ustametre/features/quotes/quotes_page.dart';
import 'package:ustametre/features/settings/settings_page.dart';

Future<void> pumpApp(WidgetTester tester) async {
  // Tipik bir Android telefon ekranı.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const UstaMetreApp());
  await tester.pumpAndSettle();
}

/// Kategori satırını listenin ortasına getirip dokunur.
Future<void> tapCategory(WidgetTester tester, String id) async {
  final tile = find.byKey(ValueKey('category_$id'));
  await tester.scrollUntilVisible(
    tile,
    200,
    scrollable: find
        .descendant(
          of: find.byType(CalculationsPage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await Scrollable.ensureVisible(tester.element(tile), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Finder navItem(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('ana sayfa marka, slogan ve 4 kısayolu gösterir', (tester) async {
    await pumpApp(tester);

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.slogan), findsOneWidget);
    for (final key in [
      'shortcut_new_calculation',
      'shortcut_new_project',
      'shortcut_new_quote',
      'shortcut_customers',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(find.text(AppStrings.newCalculation), findsOneWidget);
    expect(find.text(AppStrings.newProject), findsOneWidget);
    expect(find.text(AppStrings.newQuote), findsOneWidget);
    expect(find.text(AppStrings.customers), findsOneWidget);
  });

  testWidgets('tema renkleri tasarım paletine uygun', (tester) async {
    await pumpApp(tester);
    final theme = Theme.of(tester.element(find.text(AppStrings.slogan)));
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.gold);
    expect(theme.cardTheme.color, AppColors.card);
  });

  testWidgets('alt gezinme çubuğu 5 ekran arasında geçiş yapar', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(NavigationDestination), findsNWidgets(5));

    Future<void> go(String label, Type page) async {
      await tester.tap(navItem(label));
      await tester.pumpAndSettle();
      expect(
        find.byType(page).hitTestable(),
        findsOneWidget,
        reason: '$label sekmesi $page göstermeli',
      );
    }

    await go(AppStrings.navCalculations, CalculationsPage);
    await go(AppStrings.navProjects, ProjectsPage);
    await go(AppStrings.navQuotes, QuotesPage);
    await go(AppStrings.navSettings, SettingsPage);
    await tester.tap(navItem(AppStrings.navHome));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.slogan).hitTestable(), findsOneWidget);
  });

  testWidgets('kısayollar ilgili ekranlara götürür', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('shortcut_new_calculation')));
    await tester.pumpAndSettle();
    expect(find.byType(CalculationPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shortcut_new_project')));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectsPage).hitTestable(), findsOneWidget);

    await tester.tap(navItem(AppStrings.navHome));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shortcut_new_quote')));
    await tester.pumpAndSettle();
    expect(find.byType(QuotesPage).hitTestable(), findsOneWidget);

    await tester.tap(navItem(AppStrings.navHome));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shortcut_customers')));
    await tester.pumpAndSettle();
    expect(find.byType(CustomersPage), findsOneWidget);
  });

  testWidgets(
    'hesaplamalar ekranı 13 kategoriyi özel/genel etiketiyle listeler',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(navItem(AppStrings.navCalculations));
      await tester.pumpAndSettle();

      final list = find.descendant(
        of: find.byType(CalculationsPage),
        matching: find.byType(Scrollable),
      );
      for (final category in TradeCategories.all) {
        final tile = find.byKey(ValueKey('category_${category.id}'));
        await tester.scrollUntilVisible(tile, 200, scrollable: list.first);
        expect(find.text(category.name), findsOneWidget);
        final label = category.isAvailable
            ? AppStrings.specialCalculations
            : AppStrings.genericCalculations;
        expect(
          find.descendant(of: tile, matching: find.text(label)),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('özel hesaplı kategori seçim ekranı açar (proje / hızlı hesap)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(navItem(AppStrings.navCalculations));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mermer ve granit'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryHubPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hub_project')));
    await tester.pumpAndSettle();
    expect(find.byType(MarbleProjectPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('hub_quick')));
    await tester.pumpAndSettle();
    expect(find.byType(CalculationPage), findsOneWidget);
    expect(find.byKey(const ValueKey('mode_marbleCountertop')), findsOneWidget);
  });

  testWidgets('PVC kategorisi doğrama projesine götürür', (tester) async {
    await pumpApp(tester);
    await tester.tap(navItem(AppStrings.navCalculations));
    await tester.pumpAndSettle();
    await tapCategory(tester, 'pvc_joinery');
    await tester.tap(find.byKey(const ValueKey('hub_project')));
    await tester.pumpAndSettle();
    expect(find.byType(PvcProjectPage), findsOneWidget);
  });

  testWidgets('genel kategori doğrudan hesaplama ekranını açar', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(navItem(AppStrings.navCalculations));
    await tester.pumpAndSettle();
    await tapCategory(tester, 'ceramic_tile');
    expect(find.byType(CalculationPage), findsOneWidget);
    expect(find.byKey(const ValueKey('generic_only_note')), findsOneWidget);
  });

  testWidgets('ayarlardan fiyat listesi ve reçeteler açılır', (tester) async {
    await pumpApp(tester);
    await tester.tap(navItem(AppStrings.navSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings_price_list')));
    await tester.pumpAndSettle();
    expect(find.byType(PriceListPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings_recipes')));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeListPage), findsOneWidget);
  });

  testWidgets('hesaplamalar sekmesindeki buton yeni hesaplama açar', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(navItem(AppStrings.navCalculations));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start_calculation')));
    await tester.pumpAndSettle();
    expect(find.byType(CalculationPage), findsOneWidget);
  });

  testWidgets('kısayol kartları rahat dokunma boyutunda', (tester) async {
    await pumpApp(tester);
    final size = tester.getSize(
      find.byKey(const ValueKey('shortcut_new_calculation')),
    );
    expect(size.height, greaterThanOrEqualTo(96));
    expect(size.width, greaterThanOrEqualTo(96));
  });
}
