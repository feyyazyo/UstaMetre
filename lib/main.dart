import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app/app.dart';
import 'data/catalog_controller.dart';
import 'data/key_value_store.dart';
import 'data/records_controller.dart';
import 'data/records_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SharedPreferencesStore.open();
  final catalog = await CatalogController.load(store);

  RecordsController records;
  try {
    final path = p.join(await getDatabasesPath(), 'ustametre.db');
    final repo = await RecordsRepository.open(databaseFactory, path);
    records = RecordsController(repo);
    await records.load();
  } on Object catch (e) {
    // Veritabanı açılamazsa uygulama yine açılır; kayıt dosyası silinmez.
    records = RecordsController.unavailable('$e');
  }

  runApp(UstaMetreApp(catalog: catalog, records: records));
}
