import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/coming_soon.dart';
import '../calculations/pvc/recipe_pages.dart';
import '../price_list/price_list_page.dart';
import '../../shared/widgets/status_badge.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget item(IconData icon, String title, String subtitle) => Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: const StatusBadge(label: AppStrings.comingSoon),
        onTap: () => showComingSoon(context, title),
      ),
    );

    Widget link(
      Key key,
      IconData icon,
      String title,
      String subtitle,
      Widget page,
    ) => Card(
      child: ListTile(
        key: key,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => page)),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          link(
            const ValueKey('settings_price_list'),
            Icons.sell_outlined,
            'Fiyat Listesi',
            'Malzeme, işçilik, aksesuar, nakliye ve kendi kalemleriniz',
            const PriceListPage(),
          ),
          const SizedBox(height: 12),
          link(
            const ValueKey('settings_recipes'),
            Icons.rule_folder_outlined,
            'Profil Reçeteleri',
            'PVC doğrama için kasa, kanat ve diğer profil formülleri',
            const RecipeListPage(),
          ),
          const SizedBox(height: 12),
          item(
            Icons.badge_outlined,
            'İşletme Profili',
            'Firma adı, logo, iletişim bilgileri',
          ),
          const SizedBox(height: 12),
          item(
            Icons.payments_outlined,
            'Para Birimi ve KDV',
            'Varsayılan para birimi ve vergi oranı',
          ),
          const SizedBox(height: 12),
          item(
            Icons.straighten_outlined,
            'Ölçü Birimleri',
            'Varsayılan uzunluk birimi (mm / cm / m)',
          ),
          const SizedBox(height: 12),
          item(
            Icons.backup_outlined,
            'Yedekleme',
            'Cihazdaki verilerin yedeğini alma',
          ),
          const SizedBox(height: 24),
          Text('Hakkında', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.appName,
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    AppStrings.slogan,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sürüm 0.4.0 · Çevrimdışı çalışır; verileriniz '
                    'cihazınızda kalır.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
