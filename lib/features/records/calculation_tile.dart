import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../data/records_controller.dart';
import '../../domain/records/saved_calculation.dart';
import '../../domain/trade_category.dart';
import '../../shared/format.dart';
import '../calculations/calculation_page.dart';
import '../calculations/marble/marble_project_page.dart';
import '../calculations/pvc/pvc_project_page.dart';
import 'calculation_detail_page.dart';
import 'record_widgets.dart';

String categoryName(String id) =>
    TradeCategories.all.where((c) => c.id == id).firstOrNull?.name ?? id;

/// Kayıtlı hesabı, yapıldığı ekranda düzenlemek için açar.
Future<void> openCalculationEditor(
  BuildContext context,
  SavedCalculation calc,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => switch (calc.kind) {
      CalcKind.quick => CalculationPage(editing: calc),
      CalcKind.marbleProject => MarbleProjectPage(editing: calc),
      CalcKind.pvcProject => PvcProjectPage(editing: calc),
    },
  ),
);

Future<void> openCalculationDetail(BuildContext context, String id) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CalculationDetailPage(id: id)),
    );

/// Projeye yeni hesap eklemek için hesap türü seçtirir.
Future<void> startCalculationForProject(
  BuildContext context,
  String projectId,
) async {
  final page = await showModalBottomSheet<Widget>(
    context: context,
    backgroundColor: AppColors.card,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Hangi hesap?', style: TextStyle(fontSize: 16)),
          ),
          ListTile(
            key: const ValueKey('new_calc_marble'),
            leading: const Icon(Icons.view_quilt_outlined),
            title: const Text('Mermer tezgâh projesi'),
            onTap: () => Navigator.pop(
              context,
              MarbleProjectPage(presetProjectId: projectId),
            ),
          ),
          ListTile(
            key: const ValueKey('new_calc_pvc'),
            leading: const Icon(Icons.window_outlined),
            title: const Text('PVC doğrama projesi'),
            onTap: () => Navigator.pop(
              context,
              PvcProjectPage(presetProjectId: projectId),
            ),
          ),
          ListTile(
            key: const ValueKey('new_calc_quick'),
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('Hızlı hesap (tüm meslekler)'),
            onTap: () => Navigator.pop(
              context,
              CalculationPage(presetProjectId: projectId),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (page != null && context.mounted) {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

/// Kayıtlı hesap kartı (geçmiş, müşteri ve proje ekranlarında).
class CalculationTile extends StatelessWidget {
  const CalculationTile({super.key, required this.calc});

  final SavedCalculation calc;

  @override
  Widget build(BuildContext context) {
    final records = RecordsScope.of(context);
    final customer = records.customerById(calc.customerId);
    final project = records.projectById(calc.projectId);
    final total = calc.grandTotal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        key: ValueKey('calc_${calc.id}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openCalculationDetail(context, calc.id),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        calc.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      total?.format() ?? '—',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${categoryName(calc.categoryId)} · '
                  '${calc.current.modeLabel.isEmpty ? calc.kind.label : calc.current.modeLabel}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDateTime(calc.updatedAt)}'
                  '${calc.revisionNumber > 1 ? ' · Sürüm ${calc.revisionNumber}' : ''}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (customer != null || project != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (customer != null)
                        InfoChip(
                          icon: Icons.person_outline,
                          label: customer.name,
                        ),
                      if (project != null)
                        InfoChip(
                          icon: Icons.folder_outlined,
                          label: project.name,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
