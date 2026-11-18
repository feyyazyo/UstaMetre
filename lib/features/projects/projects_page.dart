import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/records_controller.dart';
import '../../domain/records/project.dart';
import '../../engine/money.dart';
import '../../shared/format.dart';
import '../calculations/widgets/project_scaffold.dart';
import '../customers/customers_page.dart';
import '../records/calculation_tile.dart';
import '../records/record_editors.dart';
import '../records/record_widgets.dart';

Future<void> openProjectDetail(BuildContext context, String id) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => ProjectDetailPage(id: id)));

/// Proje kartı (liste ve müşteri ayrıntısında).
class ProjectTile extends StatelessWidget {
  const ProjectTile({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final records = RecordsScope.of(context);
    final customer = records.customerById(project.customerId);
    final count = records.calculationsOfProject(project.id).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          key: ValueKey('project_${project.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: const Icon(Icons.folder_outlined, size: 30),
          title: Text(project.name),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                InfoChip(
                  icon: Icons.flag_outlined,
                  label: project.status.label,
                ),
                if (customer != null)
                  InfoChip(icon: Icons.person_outline, label: customer.name),
                InfoChip(icon: Icons.calculate_outlined, label: '$count hesap'),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openProjectDetail(context, project.id),
        ),
      ),
    );
  }
}

/// Projeler sekmesi: arama, durum filtresi, ekleme.
class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final _search = TextEditingController();
  ProjectStatus? _status;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final created = await showProjectEditor(context);
    if (created != null && mounted) {
      showMessage(context, '"${created.name}" eklendi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = RecordsScope.of(context);
    final all = records.projects;
    final list = all.where((p) {
      final customer = records.customerById(p.customerId);
      final q = _search.text;
      return (_status == null || p.status == _status) &&
          (p.matches(q) || (customer?.matches(q) ?? false));
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${AppStrings.navProjects} (${all.length})')),
      floatingActionButton: records.isAvailable
          ? FloatingActionButton.extended(
              key: const ValueKey('add_project'),
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.onGold,
              onPressed: _add,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Proje ekle'),
            )
          : null,
      body: !records.isAvailable
          ? RecordsUnavailable(error: records.error)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (all.isNotEmpty) ...[
                  TextField(
                    key: const ValueKey('project_search'),
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: 'Proje, konum veya müşteriyle ara',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in [null, ...ProjectStatus.values])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              key: ValueKey(
                                'status_filter_${s?.name ?? 'all'}',
                              ),
                              label: Text(s?.label ?? 'Tümü'),
                              selected: _status == s,
                              selectedColor: AppColors.gold,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                color: _status == s
                                    ? AppColors.onGold
                                    : AppColors.textPrimary,
                              ),
                              onSelected: (_) => setState(() => _status = s),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (all.isEmpty)
                  EmptyHint(
                    key: const ValueKey('projects_empty'),
                    icon: Icons.folder_open_outlined,
                    title: 'Henüz proje yok',
                    message:
                        'Proje oluşturup aynı işe ait hesapları (ör. mutfakta '
                        'tezgâh, denizlik, süpürgelik) bir arada tutun. '
                        'Müşteri bağlamak isteğe bağlıdır.',
                    action: FilledButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('İlk projeyi oluştur'),
                    ),
                  )
                else if (list.isEmpty)
                  const EmptyHint(
                    icon: Icons.search_off,
                    title: 'Uygun proje bulunamadı',
                    message: 'Aramayı veya durum filtresini değiştirin.',
                  )
                else
                  for (final p in list) ProjectTile(project: p),
              ],
            ),
    );
  }
}

/// Proje ayrıntısı: bilgiler, durum, bağlı hesaplar.
class ProjectDetailPage extends StatelessWidget {
  const ProjectDetailPage({super.key, required this.id});

  final String id;

  Future<void> _delete(BuildContext context, Project p) async {
    final records = RecordsScope.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final calcs = records.calculationsOfProject(p.id).length;
    final ok = await confirmAction(
      context,
      title: 'Proje silinsin mi?',
      message:
          '"${p.name}" silinecek. Bağlı $calcs hesap SİLİNMEZ; yalnızca '
          'bu projeyle bağlantıları kaldırılır.',
    );
    if (!ok) return;
    await records.deleteProject(p.id);
    nav.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('"${p.name}" silindi. Hesaplar korundu.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final records = RecordsScope.of(context);
    final p = records.projectById(id);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyHint(
          icon: Icons.search_off,
          title: 'Proje bulunamadı',
          message: 'Bu proje silinmiş olabilir.',
        ),
      );
    }
    final customer = records.customerById(p.customerId);
    final calcs = records.calculationsOfProject(p.id);
    final total = calcs.fold(
      Money.zero,
      (sum, c) => sum + (c.grandTotal ?? Money.zero),
    );

    return Scaffold(
      appBar: AppBar(title: Text(p.name, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<ProjectStatus>(
                    key: const ValueKey('project_status'),
                    initialValue: p.status,
                    isExpanded: true,
                    dropdownColor: AppColors.card,
                    decoration: const InputDecoration(labelText: 'Durum'),
                    items: [
                      for (final s in ProjectStatus.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (s) async {
                      final messenger = ScaffoldMessenger.of(context);
                      await records.saveProject(
                        id: p.id,
                        name: p.name,
                        customerId: p.customerId,
                        location: p.location,
                        note: p.note,
                        status: s!,
                      );
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(content: Text('Durum: ${s.label}')),
                        );
                    },
                  ),
                ),
                ListTile(
                  key: const ValueKey('project_customer'),
                  leading: const Icon(Icons.person_outline),
                  title: Text(customer?.name ?? 'Müşteri bağlı değil'),
                  trailing: customer == null
                      ? null
                      : const Icon(Icons.chevron_right),
                  onTap: customer == null
                      ? null
                      : () => openCustomerDetail(context, customer.id),
                ),
                if (p.location.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(p.location),
                  ),
                if (p.note.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.notes_outlined),
                    title: Text(p.note),
                  ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.event_outlined, size: 20),
                  title: Text('Oluşturuldu: ${formatDate(p.createdAt)}'),
                ),
                ItemActionsRow(
                  keyPrefix: 'project',
                  onEdit: () => showProjectEditor(context, existing: p),
                  onCopy: () => startCalculationForProject(context, p.id),
                  onDelete: () => _delete(context, p),
                  copyLabel: 'Hesap ekle',
                  copyIcon: Icons.add_chart_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hesaplar (${calcs.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (calcs.isNotEmpty)
                Text(
                  'Toplam: ${total.format()}',
                  key: const ValueKey('project_total'),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (calcs.isEmpty)
            EmptyHint(
              icon: Icons.calculate_outlined,
              title: 'Bu projede hesap yok',
              message:
                  '"Hesap ekle" ile yeni hesap başlatın; kaydederken proje '
                  'otomatik seçilir.',
              action: FilledButton.icon(
                key: const ValueKey('project_add_calc'),
                onPressed: () => startCalculationForProject(context, p.id),
                icon: const Icon(Icons.add),
                label: const Text('Hesap ekle'),
              ),
            ),
          for (final c in calcs) CalculationTile(calc: c),
        ],
      ),
    );
  }
}
