import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

/// Bir modülün durumunu gösteren küçük etiket (ör. "Özel hesap", "Yakında").
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.highlighted = false});

  final String label;

  /// `true` ise altın renkte (hazır), değilse ikincil renkte gösterilir.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.gold : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
