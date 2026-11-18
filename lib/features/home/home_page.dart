import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/records_controller.dart';
import '../../domain/trade_category.dart';
import '../records/history_page.dart';
import '../../shared/widgets/shortcut_card.dart';

/// Ana sayfa: marka başlığı, hızlı işlem kısayolları ve özet bilgiler.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onNewCalculation,
    required this.onNewProject,
    required this.onNewQuote,
    required this.onCustomers,
  });

  final VoidCallback onNewCalculation;
  final VoidCallback onNewProject;
  final VoidCallback onNewQuote;
  final VoidCallback onCustomers;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final readyCount = TradeCategories.all.where((c) => c.isAvailable).length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Text(
              AppStrings.appName,
              style: textTheme.headlineMedium?.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.slogan,
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            Text(AppStrings.quickActions, style: textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                ShortcutCard(
                  key: const ValueKey('shortcut_new_calculation'),
                  icon: Icons.calculate_outlined,
                  label: AppStrings.newCalculation,
                  onTap: onNewCalculation,
                ),
                ShortcutCard(
                  key: const ValueKey('shortcut_new_project'),
                  icon: Icons.create_new_folder_outlined,
                  label: AppStrings.newProject,
                  onTap: onNewProject,
                ),
                ShortcutCard(
                  key: const ValueKey('shortcut_new_quote'),
                  icon: Icons.request_quote_outlined,
                  label: AppStrings.newQuote,
                  onTap: onNewQuote,
                ),
                ShortcutCard(
                  key: const ValueKey('shortcut_customers'),
                  icon: Icons.people_outline,
                  label: AppStrings.customers,
                  onTap: onCustomers,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Builder(
              builder: (context) {
                final records = RecordsScope.of(context);
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    key: const ValueKey('home_history'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const Icon(Icons.history, color: AppColors.gold),
                    title: const Text('Hesap Geçmişi'),
                    subtitle: Text(
                      records.isAvailable
                          ? '${records.calculations.length} hesap · '
                                '${records.projects.length} proje · '
                                '${records.customers.length} müşteri'
                          : 'Kayıtlar şu an kullanılamıyor',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HistoryPage(),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.handyman_outlined, color: AppColors.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${TradeCategories.all.length} meslek grubu · '
                        '$readyCount grupta özel hesap hazır',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
