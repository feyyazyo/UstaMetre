import 'package:material_ui/material_ui.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_theme.dart';
import 'app_shell.dart';

class UstaMetreApp extends StatelessWidget {
  const UstaMetreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const AppShell(),
    );
  }
}
