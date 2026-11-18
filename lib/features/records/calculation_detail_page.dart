import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../data/records_controller.dart';
import '../../domain/records/saved_calculation.dart';
import '../../engine/calculator.dart';
import '../../shared/format.dart';
import '../calculations/widgets/project_scaffold.dart';
import '../calculations/widgets/result_card.dart';
import '../customers/customers_page.dart';
import '../projects/projects_page.dart';
import 'calculation_tile.dart';
import 'record_editors.dart';
import 'record_widgets.dart';

/// Kayıtlı hesabın ayrıntısı: bilgiler, bağlantılar, kayıtlı sonuç, sürümler.
class CalculationDetailPage extends StatefulWidget {
  const CalculationDetailPage({super.key, required this.id});

  final String id;

  @override
  State<CalculationDetailPage> createState() => _CalculationDetailPageState();
}

class _CalculationDetailPageState extends State<CalculationDetailPage> {
  Future<List<CalcRevision>>? _revisions;
  int? _revisionsFor;

  Future<void> _copy(SavedCalculation calc) async {
    final records = RecordsScope.of(context);
    final nav = Navigator.of(context);
    final copy = await records.duplicateCalculation(calc.id);
    if (!mounted) return;
    showMessage(context, '"${copy.name}" oluşturuldu.');
    await nav.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CalculationDetailPage(id: copy.id),
      ),
    );
  }

  Future<void> _delete(SavedCalculation calc) async {
    final records = RecordsScope.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: 'Hesap silinsin mi?',
      message:
          '"${calc.name}" ve tüm sürümleri (${calc.revisionNumber}) kalıcı '
          'olarak silinecek. Bu işlem geri alınamaz.',
    );
    if (!ok) return;
    await records.deleteCalculation(calc.id);
    nav.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('"${calc.name}" silindi.')));
  }

  @override
  Widget build(BuildContext context) {
    final records = RecordsScope.of(context);
    final calc = records.calculationById(widget.id);
    if (calc == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyHint(
          icon: Icons.search_off,
          title: 'Hesap bulunamadı',
          message: 'Bu hesap silinmiş olabilir.',
        ),
      );
    }
    if (_revisionsFor != calc.revisionNumber) {
      _revisionsFor = calc.revisionNumber;
      _revisions = records.revisions(calc.id);
    }
    final customer = records.customerById(calc.customerId);
    final project = records.projectById(calc.projectId);
    final rev = calc.current;

    Widget infoRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(calc.name, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoRow('Meslek', categoryName(calc.categoryId)),
                  infoRow(
                    'Hesap türü',
                    [
                      calc.kind.label,
                      if (rev.modeLabel.isNotEmpty) rev.modeLabel,
                    ].join(' · '),
                  ),
                  infoRow('Oluşturuldu', formatDateTime(calc.createdAt)),
                  infoRow('Son değişiklik', formatDateTime(calc.updatedAt)),
                  infoRow('Sürüm', '${calc.revisionNumber}'),
                  if (rev.note.isNotEmpty) infoRow('Not', rev.note),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('detail_customer'),
                  leading: const Icon(Icons.person_outline),
                  title: Text(customer?.name ?? 'Müşteri bağlı değil'),
                  subtitle: const Text(
                    'Müşteri',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: customer == null
                      ? null
                      : const Icon(Icons.chevron_right),
                  onTap: customer == null
                      ? null
                      : () => openCustomerDetail(context, customer.id),
                ),
                ListTile(
                  key: const ValueKey('detail_project'),
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(project?.name ?? 'Proje bağlı değil'),
                  subtitle: Text(
                    project == null
                        ? 'Proje'
                        : 'Proje · ${project.status.label}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: project == null
                      ? null
                      : const Icon(Icons.chevron_right),
                  onTap: project == null
                      ? null
                      : () => openProjectDetail(context, project.id),
                ),
                TextButton.icon(
                  key: const ValueKey('detail_links'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => _LinkEditorPage(calc: calc),
                    ),
                  ),
                  icon: const Icon(Icons.link),
                  label: const Text('Ad, müşteri ve projeyi değiştir'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ItemActionsRow(
            keyPrefix: 'detail',
            onEdit: () => openCalculationEditor(context, calc),
            onCopy: () => _copy(calc),
            onDelete: () => _delete(calc),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aşağıdaki sonuç kayıt anındaki değerlerle gösterilir; fiyat '
            'listesi sonradan değişse de değişmez. "Düzenle" ile açıp '
            'kaydettiğinizde yeni bir sürüm oluşur, bu sürüm korunur.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ResultCard(result: rev.result),
          const SizedBox(height: 16),
          Text('Sürüm geçmişi', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          FutureBuilder<List<CalcRevision>>(
            future: _revisions,
            builder: (context, snap) {
              final revs = snap.data;
              if (revs == null) return const SizedBox(height: 48);
              return Column(
                children: [
                  for (final r in revs.reversed)
                    Card(
                      key: ValueKey('revision_${r.number}'),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.gold.withValues(
                            alpha: 0.18,
                          ),
                          child: Text(
                            '${r.number}',
                            style: const TextStyle(color: AppColors.gold),
                          ),
                        ),
                        title: Text(
                          r.number == calc.revisionNumber
                              ? 'Sürüm ${r.number} (güncel)'
                              : 'Sürüm ${r.number}',
                        ),
                        subtitle: Text(
                          formatDateTime(r.savedAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Text(r.grandTotal?.format() ?? '—'),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                _RevisionPage(name: calc.name, revision: r),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Eski bir sürümün salt okunur görünümü.
class _RevisionPage extends StatelessWidget {
  const _RevisionPage({required this.name, required this.revision});

  final String name;
  final CalcRevision revision;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('$name · Sürüm ${revision.number}')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Kaydedildi: ${formatDateTime(revision.savedAt)}'
          '${revision.note.isEmpty ? '' : '\nNot: ${revision.note}'}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        ResultCard(result: revision.result),
      ],
    ),
  );
}

/// Yeni sürüm oluşturmadan ad, müşteri ve proje bağlantısını değiştirir.
class _LinkEditorPage extends StatefulWidget {
  const _LinkEditorPage({required this.calc});

  final SavedCalculation calc;

  @override
  State<_LinkEditorPage> createState() => _LinkEditorPageState();
}

class _LinkEditorPageState extends State<_LinkEditorPage> {
  late final _name = TextEditingController(text: widget.calc.name);
  late String? _customerId = widget.calc.customerId;
  late String? _projectId = widget.calc.projectId;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    try {
      await RecordsScope.of(context).updateCalculation(
        widget.calc.id,
        name: _name.text,
        customerId: _customerId,
        projectId: _projectId,
        clearCustomer: _customerId == null,
        clearProject: _projectId == null,
      );
      nav.pop();
    } on CalculationException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => EditorScaffold(
    title: 'Bilgileri düzenle',
    saveKey: 'links_save',
    onSave: _save,
    isDirty: false,
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const ValueKey('links_name'),
          controller: _name,
          decoration: const InputDecoration(labelText: 'Hesap adı *'),
        ),
        const SizedBox(height: 12),
        CustomerPicker(
          fieldKey: 'links_customer',
          value: _customerId,
          onChanged: (id) => setState(() => _customerId = id),
        ),
        const SizedBox(height: 12),
        ProjectPicker(
          value: _projectId,
          customerIdForNew: _customerId,
          onChanged: (id) => setState(() => _projectId = id),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Bu değişiklik hesabın tutarlarını etkilemez ve yeni sürüm '
          'oluşturmaz.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}
