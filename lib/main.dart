import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'data/catalog_controller.dart';
import 'data/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SharedPreferencesStore.open();
  final catalog = await CatalogController.load(store);
  runApp(UstaMetreApp(catalog: catalog));
}
