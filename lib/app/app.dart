import 'package:material_ui/material_ui.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../data/catalog_controller.dart';
import '../data/catalog_scope.dart';
import '../data/key_value_store.dart';
import '../data/records_controller.dart';
import 'app_shell.dart';

class UstaMetreApp extends StatefulWidget {
  /// [catalog] verilmezse bellek içi (kalıcı olmayan) katalog kullanılır.
  const UstaMetreApp({super.key, this.catalog, this.records});

  final CatalogController? catalog;

  /// Verilmezse kayıt özellikleri "kullanılamıyor" olarak gösterilir.
  final RecordsController? records;

  @override
  State<UstaMetreApp> createState() => _UstaMetreAppState();
}

class _UstaMetreAppState extends State<UstaMetreApp> {
  late final CatalogController _catalog =
      widget.catalog ?? CatalogController(store: MemoryStore());
  late final RecordsController _records =
      widget.records ??
      RecordsController.unavailable('Kayıt deposu bağlı değil.');

  @override
  Widget build(BuildContext context) {
    return RecordsScope(
      controller: _records,
      child: CatalogScope(
        controller: _catalog,
        child: MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: const AppShell(),
        ),
      ),
    );
  }
}
