import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../engine/calculators/pvc_joinery_calculator.dart';

IconData joineryIcon(JoineryType type) => switch (type) {
  JoineryType.window => Icons.window_outlined,
  JoineryType.door => Icons.door_front_door_outlined,
  JoineryType.balconyDoor => Icons.balcony_outlined,
};

/// Pencere / Kapı / Balkon kapısı seçimi: ikonlu, büyük, tek dokunuşla
/// seçilebilen üç kart. Dar ekranda da etiketler kesilmez.
class JoineryTypePicker extends StatelessWidget {
  const JoineryTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final JoineryType value;
  final ValueChanged<JoineryType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, t) in JoineryType.values.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              selected: t == value,
              button: true,
              label: t.label,
              child: InkWell(
                key: ValueKey('j_type_${t.name}'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => onChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  constraints: const BoxConstraints(minHeight: 96),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: t == value
                        ? AppColors.gold.withValues(alpha: 0.18)
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: t == value ? AppColors.gold : AppColors.outline,
                      width: t == value ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        joineryIcon(t),
                        size: 32,
                        color: t == value
                            ? AppColors.gold
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: t == value
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: t == value
                              ? AppColors.gold
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
