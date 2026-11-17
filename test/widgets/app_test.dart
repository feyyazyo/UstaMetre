import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustametre/app/app.dart';
import 'package:ustametre/core/constants/app_strings.dart';
import 'package:ustametre/core/theme/app_colors.dart';
import 'package:ustametre/domain/trade_category.dart';
import 'package:ustametre/features/calculations/calculations_page.dart';
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
    expect(find.byType(CalculationsPage).hitTestable(), findsOneWidget);

    await tester.tap(navItem(AppStrings.navHome));
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

  testWidgets('hesaplamalar ekranı 12 kategoriyi "Yakında" olarak listeler', (
    tester,
  ) async {
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
      expect(
        find.descendant(of: tile, matching: find.text(AppStrings.comingSoon)),
        findsOneWidget,
      );
    }
  });

  testWidgets('henüz hazır olmayan kategoriye dokununca bilgi verilir', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(navItem(AppStrings.navCalculations));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mermer ve granit'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining(AppStrings.comingSoonMessage), findsOneWidget);
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
