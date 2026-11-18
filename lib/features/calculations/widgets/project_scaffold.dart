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

/// Liste öğeleri için her zaman görünen Düzenle / Kopyala / Sil butonları.
///
/// Gizli "⋮" menüsü yerine kullanılır; telefonda tek dokunuşla erişilir.
/// Butonların anahtarları `<keyPrefix>_edit`, `_copy`, `_delete` olur.
class ItemActionsRow extends StatelessWidget {
  const ItemActionsRow({
    super.key,
    required this.keyPrefix,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    this.copyLabel = 'Kopyala',
    this.copyIcon = Icons.copy_outlined,
  });

  final String keyPrefix;
  final String copyLabel;
  final IconData copyIcon;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    Widget action(
      String suffix,
      IconData icon,
      String label,
      VoidCallback f, {
      Color? color,
    }) => Expanded(
      child: TextButton.icon(
        key: ValueKey('${keyPrefix}_$suffix'),
        style: TextButton.styleFrom(
          foregroundColor: color ?? AppColors.gold,
          minimumSize: const Size.fromHeight(48),
        ),
        onPressed: f,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
    return Row(
      children: [
        action('edit', Icons.edit_outlined, 'Düzenle', onEdit),
        action('copy', copyIcon, copyLabel, onCopy),
        action(
          'delete',
          Icons.delete_outline,
          'Sil',
          onDelete,
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }
}

/// Kaydedilmemiş değişiklikle çıkılmak istendiğinde sorar. `true` dönerse
/// çıkılır.
Future<bool> confirmDiscard(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Kaydedilmedi'),
      content: const Text(
        'Girdiğiniz bilgiler kaydedilmedi. Kaydetmeden çıkmak istiyor '
        'musunuz?',
      ),
      actions: [
        TextButton(
          key: const ValueKey('discard_cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Düzenlemeye dön'),
        ),
        TextButton(
          key: const ValueKey('discard_confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Kaydetmeden çık'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Tam ekran editörler için ortak iskelet:
/// * Üst çubukta her zaman görünen **Kaydet** (klavye açıkken de erişilir)
/// * Kaydedilmemiş değişiklik varken geri / X basılırsa onay sorulur
class EditorScaffold extends StatelessWidget {
  const EditorScaffold({
    super.key,
    required this.title,
    required this.saveKey,
    required this.onSave,
    required this.isDirty,
    required this.body,
  });

  final String title;
  final String saveKey;
  final VoidCallback onSave;
  final bool isDirty;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await confirmDiscard(context)) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                key: ValueKey('${saveKey}_top'),
                style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
                onPressed: onSave,
                child: const Text('Kaydet'),
              ),
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}
