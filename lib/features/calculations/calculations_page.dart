import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/trade_category.dart';
import '../../shared/widgets/status_badge.dart';
import 'calculation_page.dart';
import 'category_icons.dart';

/// Hesaplamalar sekmesi: yeni hesaplama başlatma ve meslek kategorileri.
class CalculationsPage extends StatelessWidget {
  const CalculationsPage({super.key, this.categories = TradeCategories.all});

  final List<TradeCategory> categories;

  static void openCalculation(BuildContext context, {String? categoryId}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalculationPage(initialCategoryId: categoryId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navCalculations)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: categories.length + 2,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return FilledButton.icon(
              key: const ValueKey('start_calculation'),
              onPressed: () => openCalculation(context),
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.newCalculation),
            );
          }
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Meslek grubunu seçin. "Özel hesap" etiketli gruplarda '
                'mesleğe özel hesaplar, diğerlerinde genel hesaplar '
                '(uzunluk, alan, hacim, metre tül, çevre, adet, manuel) '
                'kullanılabilir.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          final category = categories[index - 2];
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
              trailing: StatusBadge(
                label: category.isAvailable
                    ? AppStrings.specialCalculations
                    : AppStrings.genericCalculations,
                highlighted: category.isAvailable,
              ),
              onTap: () => openCalculation(context, categoryId: category.id),
            ),
          );
        },
      ),
    );
  }
}
