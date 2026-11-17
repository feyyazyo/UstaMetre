import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/trade_category.dart';
import '../../shared/widgets/coming_soon.dart';
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
        trailing: const StatusBadge(status: ModuleStatus.planned),
        onTap: () => showComingSoon(context, title),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
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
                    'Sürüm 0.1.0 · Çevrimdışı çalışır; verileriniz '
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
