import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';

/// Henüz uygulanmamış bir özelliğe dokunulduğunda kullanıcıyı dürüstçe
/// bilgilendirir.
void showComingSoon(BuildContext context, String featureName) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$featureName: ${AppStrings.comingSoonMessage}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
