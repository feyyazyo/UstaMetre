import 'package:material_ui/material_ui.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../data/catalog_controller.dart';
import '../data/catalog_scope.dart';
import '../data/key_value_store.dart';
import 'app_shell.dart';

class UstaMetreApp extends StatefulWidget {
  /// [catalog] verilmezse bellek içi (kalıcı olmayan) katalog kullanılır.
  const UstaMetreApp({super.key, this.catalog});

  final CatalogController? catalog;

  @override
  State<UstaMetreApp> createState() => _UstaMetreAppState();
}

class _UstaMetreAppState extends State<UstaMetreApp> {
  late final CatalogController _catalog =
      widget.catalog ?? CatalogController(store: MemoryStore());

  @override
  Widget build(BuildContext context) {
    return CatalogScope(
      controller: _catalog,
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const AppShell(),
      ),
    );
  }
}
