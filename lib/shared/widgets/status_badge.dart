import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/trade_category.dart';

/// Bir modülün durumunu (Hazır / Yakında) gösteren küçük etiket.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ModuleStatus status;

  @override
  Widget build(BuildContext context) {
    final available = status == ModuleStatus.available;
    final color = available ? AppColors.gold : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
