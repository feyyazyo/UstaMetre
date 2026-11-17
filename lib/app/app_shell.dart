import 'package:material_ui/material_ui.dart';

import '../core/constants/app_strings.dart';
import '../features/calculations/calculations_page.dart';
import '../features/customers/customers_page.dart';
import '../features/home/home_page.dart';
import '../features/projects/projects_page.dart';
import '../features/quotes/quotes_page.dart';
import '../features/settings/settings_page.dart';

/// Alt gezinme çubuğundaki sekmeler.
enum AppTab { home, calculations, projects, quotes, settings }

/// Alt gezinme çubuğu ile 5 ana ekranı barındıran kabuk.
///
/// Gezinme çubuğu ekranın altında olduğundan tek elle kullanım kolaydır.
/// Sekmeler [IndexedStack] ile tutulur; sekme değiştirildiğinde durum kaybolmaz.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTab = AppTab.home});

  final AppTab initialTab;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppTab _tab = widget.initialTab;

  void _select(AppTab tab) => setState(() => _tab = tab);

  void _openCustomers() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const CustomersPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          HomePage(
            onNewCalculation: () => _select(AppTab.calculations),
            onNewProject: () => _select(AppTab.projects),
            onNewQuote: () => _select(AppTab.quotes),
            onCustomers: _openCustomers,
          ),
          const CalculationsPage(),
          const ProjectsPage(),
          const QuotesPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => _select(AppTab.values[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: AppStrings.navHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: AppStrings.navCalculations,
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: AppStrings.navProjects,
          ),
          NavigationDestination(
            icon: Icon(Icons.request_quote_outlined),
            selectedIcon: Icon(Icons.request_quote),
            label: AppStrings.navQuotes,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: AppStrings.navSettings,
          ),
        ],
      ),
    );
  }
}
