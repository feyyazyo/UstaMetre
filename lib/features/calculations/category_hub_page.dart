import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/trade_category.dart';
import 'calculation_page.dart';
import 'marble/marble_project_page.dart';
import 'pvc/pvc_project_page.dart';

/// Özel hesabı olan kategoriler için seçim ekranı: mesleğe özel proje
/// hesabı veya genel hızlı hesap.
class CategoryHubPage extends StatelessWidget {
  const CategoryHubPage({super.key, required this.category});

  final TradeCategory category;

  /// Kategorinin özel proje ekranı varsa onu, yoksa `null` döner.
  static Widget? projectPageFor(String categoryId) => switch (categoryId) {
    'marble_granite' => const MarbleProjectPage(),
    'pvc_joinery' => const PvcProjectPage(),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final project = projectPageFor(category.id);
    final (title, subtitle) = switch (category.id) {
      'marble_granite' => (
        'Tezgâh projesi',
        'Çok parçalı tezgâh, sakal/pah/rodaj/kenar işleme, evye, ocak, '
            'delikler, nakliye, montaj',
      ),
      'pvc_joinery' => (
        'Doğrama projesi',
        'Pencere, kapı, balkon kapısı; cam, profil, aksesuar, sineklik, '
            'montaj, nakliye',
      ),
      _ => ('Proje hesabı', ''),
    };

    Widget option({
      required Key key,
      required IconData icon,
      required String title,
      required String subtitle,
      required Widget page,
    }) => Card(
      child: ListTile(
        key: key,
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 32),
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => page)),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (project != null)
            option(
              key: const ValueKey('hub_project'),
              icon: Icons.assignment_outlined,
              title: title,
              subtitle: subtitle,
              page: project,
            ),
          const SizedBox(height: 12),
          option(
            key: const ValueKey('hub_quick'),
            icon: Icons.calculate_outlined,
            title: 'Hızlı hesap',
            subtitle: 'Uzunluk, alan, hacim, metre tül, çevre, adet, manuel',
            page: CalculationPage(initialCategoryId: category.id),
          ),
        ],
      ),
    );
  }
}
