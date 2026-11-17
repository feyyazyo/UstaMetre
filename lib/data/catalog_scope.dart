import 'package:material_ui/material_ui.dart';

import 'catalog_controller.dart';

/// [CatalogController]'ı widget ağacına sağlar; değişikliklerde bağımlı
/// widget'lar yeniden çizilir.
class CatalogScope extends InheritedNotifier<CatalogController> {
  const CatalogScope({
    super.key,
    required CatalogController controller,
    required super.child,
  }) : super(notifier: controller);

  static CatalogController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CatalogScope>();
    assert(scope != null, 'CatalogScope bulunamadı');
    return scope!.notifier!;
  }
}
