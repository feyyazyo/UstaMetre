import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../data/records_controller.dart';
import '../../domain/records/saved_calculation.dart';
import '../../domain/trade_category.dart';
import '../../engine/calculator.dart';
import '../../shared/format.dart';
import '../calculations/widgets/project_scaffold.dart';
import 'record_editors.dart';
import 'record_widgets.dart';

/// Kayıt sonrası sonuç.
final class SaveOutcome {
  const SaveOutcome(this.calculation, {required this.asNewRevision});

  final SavedCalculation calculation;

  /// `true`: mevcut hesaba yeni sürüm eklendi; `false`: yeni hesap oluştu.
  final bool asNewRevision;
}

/// Hesabı kaydetme sayfasını açar.
///
/// [existing] verilirse (düzenleme) varsayılan davranış **yeni sürüm**
/// eklemektir; önceki sürüm korunur. Kullanıcı "ayrı yeni hesap olarak
/// kaydet"i de seçebilir.
Future<SaveOutcome?> showSaveCalculation(
  BuildContext context, {
  required CalcRevision revision,
  SavedCalculation? existing,
  String? presetProjectId,
}) {
  final records = RecordsScope.of(context);
  if (!records.isAvailable) {
    showMessage(context, 'Kayıtlar şu an kullanılamıyor: ${records.error}');
    return Future.value();
  }
  return Navigator.of(context).push<SaveOutcome>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SaveCalculationPage(
        revision: revision,
        existing: existing,
        presetProjectId: presetProjectId,
      ),
    ),
  );
}

/// Kaydetmeden önce sonucun hazır olduğunu denetler ve kayıt sayfasını açar;
/// kayıttan sonra kısa bir bildirim gösterir. Kaydedilen hesabı döner.
Future<SavedCalculation?> saveFromCalculator(
  BuildContext context, {
  required CalcRevision? revision,
  SavedCalculation? existing,
  String? presetProjectId,
}) async {
  if (revision == null) {
    showMessage(
      context,
      'Kaydetmek için önce hesabı tamamlayın (eksik veya hatalı alanlar var).',
    );
    return null;
  }
  final messenger = ScaffoldMessenger.of(context);
  final outcome = await showSaveCalculation(
    context,
    revision: revision,
    existing: existing,
    presetProjectId: presetProjectId,
  );
  if (outcome == null) return null;
  final c = outcome.calculation;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          outcome.asNewRevision
              ? '"${c.name}" güncellendi (sürüm ${c.revisionNumber}). '
                    'Önceki sürüm korundu.'
              : '"${c.name}" kaydedildi.',
        ),
      ),
    );
  return c;
}

/// Önerilen hesap adı: "Mermer ve granit · Alan (m²) · 18.11.2026"
String suggestCalculationName(CalcRevision r) {
  final category = TradeCategories.all
      .where((c) => c.id == r.categoryId)
      .firstOrNull;
  return [
    category?.name ?? 'Hesap',
    if (r.modeLabel.isNotEmpty) r.modeLabel,
    formatDate(DateTime.now()),
  ].join(' · ');
}

class SaveCalculationPage extends StatefulWidget {
  const SaveCalculationPage({
    super.key,
    required this.revision,
    this.existing,
    this.presetProjectId,
  });

  final CalcRevision revision;
  final SavedCalculation? existing;
  final String? presetProjectId;

  @override
  State<SaveCalculationPage> createState() => _SaveCalculationPageState();
}

class _SaveCalculationPageState extends State<SaveCalculationPage> {
  late final _name = TextEditingController(
    text: widget.existing?.name ?? suggestCalculationName(widget.revision),
  );
  late final _note = TextEditingController(text: widget.revision.note);
  late String? _customerId = widget.existing?.customerId;
  late String? _projectId =
      widget.existing?.projectId ?? widget.presetProjectId;
  bool _asNewRevision = true;
  bool _initialized = false;
  String? _error;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // Önceden seçilen projenin müşterisi varsa onu da seç.
    final project = RecordsScope.of(context).projectById(_projectId);
    _customerId ??= project?.customerId;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _selectProject(String? id) {
    final project = RecordsScope.of(context).projectById(id);
    setState(() {
      _projectId = id;
      if (_customerId == null && project?.customerId != null) {
        _customerId = project!.customerId;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final records = RecordsScope.of(context);
    final nav = Navigator.of(context);
    final revision = widget.revision.copyWith(note: _note.text.trim());
    final existing = widget.existing;
    try {
      final SaveOutcome outcome;
      if (existing != null && _asNewRevision) {
        final saved = await records.updateCalculation(
          existing.id,
          name: _name.text,
          revision: revision,
          customerId: _customerId,
          projectId: _projectId,
          clearCustomer: _customerId == null,
          clearProject: _projectId == null,
        );
        outcome = SaveOutcome(saved, asNewRevision: true);
      } else {
        final saved = await records.createCalculation(
          name: _name.text,
          revision: revision,
          customerId: _customerId,
          projectId: _projectId,
        );
        outcome = SaveOutcome(saved, asNewRevision: false);
      }
      nav.pop(outcome);
    } on CalculationException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final total = widget.revision.grandTotal;
    return EditorScaffold(
      title: existing == null ? 'Hesabı kaydet' : 'Değişiklikleri kaydet',
      saveKey: 'save_calc',
      onSave: _save,
      // Kaydetmeden çıkmak hesabı kaybettirmez (hesap ekranı açık kalır).
      isDirty: false,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: Text(widget.revision.kind.label),
              subtitle: Text(
                widget.revision.modeLabel,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: Text(
                total?.format() ?? 'Tutar yok',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('save_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(labelText: 'Hesap adı *'),
          ),
          const SizedBox(height: 12),
          CustomerPicker(
            fieldKey: 'save_customer',
            value: _customerId,
            onChanged: (id) => setState(() => _customerId = id),
          ),
          const SizedBox(height: 12),
          ProjectPicker(
            value: _projectId,
            customerIdForNew: _customerId,
            onChanged: _selectProject,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('save_note'),
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)'),
          ),
          if (existing != null) ...[
            const SizedBox(height: 16),
            RadioGroup<bool>(
              groupValue: _asNewRevision,
              onChanged: (v) => setState(() => _asNewRevision = v!),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    key: const ValueKey('save_as_revision'),
                    value: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Sürüm ${existing.revisionNumber + 1} olarak kaydet',
                    ),
                    subtitle: const Text(
                      'Önceki sürüm silinmez; hesap geçmişinden görülebilir.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const RadioListTile<bool>(
                    key: ValueKey('save_as_new'),
                    value: false,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Ayrı yeni hesap olarak kaydet'),
                    subtitle: Text(
                      'Mevcut hesap olduğu gibi kalır.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                key: const ValueKey('save_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Ölçüler, birim fiyatlar, ek kalemler, indirim ve KDV bu anki '
            'değerleriyle saklanır. Fiyat listesi sonradan değişse de bu '
            'kayıt değişmez.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('save_calc'),
            onPressed: _save,
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

/// Hesap ekranlarının üst çubuğundaki **Kaydet** butonu.
class SaveCalculationAction extends StatelessWidget {
  const SaveCalculationAction({
    super.key,
    required this.onPressed,
    required this.enabled,
  });

  final VoidCallback onPressed;

  /// Sonuç hazır değilse soluk görünür; basılınca nedenini açıklar.
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilledButton.icon(
      key: const ValueKey('save_calculation'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(96, 44),
        backgroundColor: enabled
            ? AppColors.gold
            : AppColors.gold.withValues(alpha: 0.35),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.save_outlined, size: 20),
      label: const Text('Kaydet'),
    ),
  );
}
