import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/records_controller.dart';
import '../../domain/records/customer.dart';
import '../../shared/format.dart';
import '../calculations/widgets/project_scaffold.dart';
import '../records/calculation_tile.dart';
import '../records/record_editors.dart';
import '../records/record_widgets.dart';
import '../projects/projects_page.dart';

Future<void> openCustomerDetail(BuildContext context, String id) =>
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => CustomerDetailPage(id: id)));

/// Müşteri listesi: arama, ekleme, ayrıntıya geçiş.
class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _search = TextEditingController();

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
    final created = await showCustomerEditor(context);
    if (created != null && mounted) {
      showMessage(context, '"${created.name}" eklendi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = RecordsScope.of(context);
    final all = records.customers;
    final list = all.where((c) => c.matches(_search.text)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppStrings.customersTitle} (${all.length})'),
      ),
      floatingActionButton: records.isAvailable
          ? FloatingActionButton.extended(
              key: const ValueKey('add_customer'),
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.onGold,
              onPressed: _add,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Müşteri ekle'),
            )
          : null,
      body: !records.isAvailable
          ? RecordsUnavailable(error: records.error)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (all.isNotEmpty)
                  TextField(
                    key: const ValueKey('customer_search'),
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: 'Ad, telefon, e-posta veya adresle ara',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                const SizedBox(height: 12),
                if (all.isEmpty)
                  EmptyHint(
                    key: const ValueKey('customers_empty'),
                    icon: Icons.people_outline,
                    title: 'Henüz müşteri yok',
                    message:
                        'Müşteri ekleyerek projelerinizi ve hesaplarınızı '
                        'müşteriye göre takip edebilirsiniz. Telefon ve diğer '
                        'bilgiler isteğe bağlıdır.',
                    action: FilledButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('İlk müşteriyi ekle'),
                    ),
                  )
                else if (list.isEmpty)
                  const EmptyHint(
                    icon: Icons.search_off,
                    title: 'Uygun müşteri bulunamadı',
                    message: 'Farklı bir arama deneyin.',
                  )
                else
                  for (final c in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          key: ValueKey('customer_${c.id}'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: const Icon(Icons.person_outline, size: 30),
                          title: Text(c.name),
                          subtitle: Text(
                            [
                              if (c.phone.isNotEmpty) c.phone,
                              '${records.projectsOf(c.id).length} proje',
                              '${records.calculationsOfCustomer(c.id).length} hesap',
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => openCustomerDetail(context, c.id),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}

/// Müşteri ayrıntısı: bilgiler, projeleri ve hesapları.
class CustomerDetailPage extends StatelessWidget {
  const CustomerDetailPage({super.key, required this.id});

  final String id;

  Future<void> _delete(BuildContext context, Customer c) async {
    final records = RecordsScope.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final projects = records.projectsOf(c.id).length;
    final calcs = records.calculationsOfCustomer(c.id).length;
    final ok = await confirmAction(
      context,
      title: 'Müşteri silinsin mi?',
      message:
          '"${c.name}" silinecek. Bağlı $projects proje ve $calcs hesap '
          'SİLİNMEZ; yalnızca bu müşteriyle bağlantıları kaldırılır.',
    );
    if (!ok) return;
    await records.deleteCustomer(c.id);
    nav.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${c.name}" silindi. Projeler ve hesaplar korundu.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final records = RecordsScope.of(context);
    final c = records.customerById(id);
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyHint(
          icon: Icons.search_off,
          title: 'Müşteri bulunamadı',
          message: 'Bu müşteri silinmiş olabilir.',
        ),
      );
    }
    final projects = records.projectsOf(c.id);
    final calcs = records.calculationsOfCustomer(c.id);

    Widget info(IconData icon, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : ListTile(
            dense: true,
            leading: Icon(icon, size: 20),
            title: Text(value),
          );

    return Scaffold(
      appBar: AppBar(title: Text(c.name, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info(Icons.phone_outlined, c.phone),
                info(Icons.email_outlined, c.email),
                info(Icons.place_outlined, c.address),
                info(Icons.notes_outlined, c.note),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.event_outlined, size: 20),
                  title: Text('Eklendi: ${formatDate(c.createdAt)}'),
                ),
                ItemActionsRow(
                  keyPrefix: 'customer',
                  onEdit: () => showCustomerEditor(context, existing: c),
                  // Kopyalama yerine bu müşteriye yeni proje eklenir.
                  onCopy: () =>
                      showProjectEditor(context, presetCustomerId: c.id),
                  onDelete: () => _delete(context, c),
                  copyLabel: 'Yeni proje',
                  copyIcon: Icons.create_new_folder_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Projeler (${projects.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (projects.isEmpty)
            const Text(
              'Bu müşteriye bağlı proje yok. "Yeni proje" ile ekleyebilirsiniz.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          for (final p in projects) ProjectTile(project: p),
          const SizedBox(height: 16),
          Text(
            'Hesaplar (${calcs.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (calcs.isEmpty)
            const Text(
              'Bu müşteriye bağlı hesap yok. Hesabı kaydederken müşteri '
              'seçebilirsiniz.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          for (final calc in calcs) CalculationTile(calc: calc),
        ],
      ),
    );
  }
}
