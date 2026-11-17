import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../engine/measurement.dart';

/// Proje hesap ekranlarında bölüm başlığı.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
      ],
    ),
  );
}

/// mm / cm / m seçici.
class LengthUnitSelector extends StatelessWidget {
  const LengthUnitSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final LengthUnit value;
  final ValueChanged<LengthUnit> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<LengthUnit>(
    key: const ValueKey('unit_select'),
    showSelectedIcon: false,
    style: SegmentedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      selectedBackgroundColor: AppColors.gold,
      selectedForegroundColor: AppColors.onGold,
    ),
    segments: [
      for (final u in LengthUnit.values)
        ButtonSegment(
          value: u,
          label: Text(u.symbol, key: ValueKey('unit_${u.name}')),
        ),
    ],
    selected: {value},
    onSelectionChanged: (s) => onChanged(s.first),
  );
}

/// Liste öğeleri için Düzenle / Kopyala / Sil menüsü.
class ItemActionsMenu extends StatelessWidget {
  const ItemActionsMenu({
    super.key,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    color: AppColors.card,
    onSelected: (a) => switch (a) {
      'edit' => onEdit(),
      'copy' => onCopy(),
      _ => onDelete(),
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'edit', child: Text('Düzenle')),
      PopupMenuItem(value: 'copy', child: Text('Kopyala')),
      PopupMenuItem(value: 'delete', child: Text('Sil')),
    ],
  );
}
