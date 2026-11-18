import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

/// Silme gibi geri alınamaz işlemlerden önce açık onay ister.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Sil',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          key: const ValueKey('confirm_cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('confirm_ok'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(96, 44),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Kısa bilgi mesajı.
void showMessage(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

/// Boş liste durumunda yönlendirici açıklama.
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 48, color: AppColors.gold),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

/// Kayıt deposu açılamadığında gösterilir.
class RecordsUnavailable extends StatelessWidget {
  const RecordsUnavailable({super.key, required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) => EmptyHint(
    key: const ValueKey('records_unavailable'),
    icon: Icons.storage_outlined,
    title: 'Kayıtlar şu an açılamıyor',
    message:
        'Cihazdaki kayıt dosyası açılamadı; dosya silinmedi. '
        '${error ?? ''}',
  );
}

/// Küçük bilgi etiketi (durum, müşteri, proje).
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.outline),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.gold),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}
