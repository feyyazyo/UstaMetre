import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/trade_category.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/status_badge.dart';
import 'category_icons.dart';

/// Meslek kategorilerinin listelendiği hesaplamalar ekranı.
class CalculationsPage extends StatelessWidget {
  const CalculationsPage({super.key, this.categories = TradeCategories.all});

  final List<TradeCategory> categories;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navCalculations)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(
              'Meslek grubunu seçin',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            );
          }
          final category = categories[index - 1];
          return Card(
            child: ListTile(
              key: ValueKey('category_${category.id}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Icon(categoryIcon(category.id), size: 28),
              title: Text(
                category.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                category.description,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: StatusBadge(status: category.status),
              onTap: () {
                if (!category.isAvailable) {
                  showComingSoon(context, category.name);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
