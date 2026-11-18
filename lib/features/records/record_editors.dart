import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../data/records_controller.dart';
import '../../domain/records/customer.dart';
import '../../domain/records/project.dart';
import '../../engine/calculator.dart';
import '../calculations/widgets/project_scaffold.dart';

/// Müşteri ekler/düzenler; kaydedilen müşteriyi döner.
Future<Customer?> showCustomerEditor(
  BuildContext context, {
  Customer? existing,
}) => Navigator.of(context).push<Customer>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => CustomerEditorPage(existing: existing),
  ),
);

/// Proje ekler/düzenler; kaydedilen projeyi döner.
Future<Project?> showProjectEditor(
  BuildContext context, {
  Project? existing,
  String? presetCustomerId,
}) => Navigator.of(context).push<Project>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ProjectEditorPage(
      existing: existing,
      presetCustomerId: presetCustomerId,
    ),
  ),
);

class CustomerEditorPage extends StatefulWidget {
  const CustomerEditorPage({super.key, this.existing});

  final Customer? existing;

  @override
  State<CustomerEditorPage> createState() => _CustomerEditorPageState();
}

class _CustomerEditorPageState extends State<CustomerEditorPage> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _address = TextEditingController(
    text: widget.existing?.address ?? '',
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late final _initial = [for (final c in _all) c.text];
  String? _error;
  bool _saving = false;

  List<TextEditingController> get _all => [
    _name,
    _phone,
    _email,
    _address,
    _note,
  ];

  @override
  void initState() {
    super.initState();
    _initial; // başlangıç değerleri
    for (final c in _all) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    try {
      final saved = await RecordsScope.of(context).saveCustomer(
        id: widget.existing?.id,
        name: _name.text,
        phone: _phone.text,
        email: _email.text,
        address: _address.text,
        note: _note.text,
      );
      nav.pop(saved);
    } on CalculationException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dirty = [for (final (i, c) in _all.indexed) c.text != _initial[i]]
        .any((x) => x);
    Widget field(
      String key,
      TextEditingController c,
      String label, {
      TextInputType? keyboard,
      int maxLines = 1,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: ValueKey(key),
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        textCapitalization: keyboard == null
            ? TextCapitalization.words
            : TextCapitalization.none,
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(labelText: label),
      ),
    );
    return EditorScaffold(
      title: widget.existing == null ? 'Yeni müşteri' : 'Müşteriyi düzenle',
      saveKey: 'cust_save',
      onSave: _save,
      isDirty: dirty,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field('cust_name', _name, 'Ad soyad veya firma adı *'),
          field(
            'cust_phone',
            _phone,
            'Telefon (isteğe bağlı)',
            keyboard: TextInputType.phone,
          ),
          field(
            'cust_email',
            _email,
            'E-posta (isteğe bağlı)',
            keyboard: TextInputType.emailAddress,
          ),
          field(
            'cust_address',
            _address,
            'Adres (isteğe bağlı)',
            keyboard: TextInputType.streetAddress,
            maxLines: 2,
          ),
          field(
            'cust_note',
            _note,
            'Açıklama (isteğe bağlı)',
            keyboard: TextInputType.multiline,
            maxLines: 3,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                key: const ValueKey('cust_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            key: const ValueKey('cust_save'),
            onPressed: _save,
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

/// Müşteri seçimi: "Müşteri yok", mevcut müşteriler ve "Yeni müşteri".
class CustomerPicker extends StatelessWidget {
  const CustomerPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.fieldKey = 'customer_picker',
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String fieldKey;

  static const _newValue = '__new__';

  @override
  Widget build(BuildContext context) {
    final records = RecordsScope.of(context);
    return DropdownButtonFormField<String?>(
      key: ValueKey(fieldKey),
      initialValue: records.customerById(value) == null ? null : value,
      isExpanded: true,
      dropdownColor: AppColors.card,
      decoration: const InputDecoration(labelText: 'Müşteri (isteğe bağlı)'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Müşteri yok')),
        for (final c in records.customers)
          DropdownMenuItem(
            value: c.id,
            child: Text(c.name, overflow: TextOverflow.ellipsis),
          ),
        const DropdownMenuItem(
          value: _newValue,
          child: Text(
            '＋ Yeni müşteri oluştur',
            style: TextStyle(color: AppColors.gold),
          ),
        ),
      ],
      onChanged: (id) async {
        if (id != _newValue) {
          onChanged(id);
          return;
        }
        final created = await showCustomerEditor(context);
        onChanged(created?.id ?? value);
      },
    );
  }
}

/// Proje seçimi: "Proje yok", projeler ve "Yeni proje".
class ProjectPicker extends StatelessWidget {
  const ProjectPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.customerIdForNew,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  /// Yeni proje oluşturulurken önceden seçilecek müşteri.
  final String? customerIdForNew;

  static const _newValue = '__new__';

  @override
  Widget build(BuildContext context) {
    final records = RecordsScope.of(context);
    return DropdownButtonFormField<String?>(
      key: const ValueKey('project_picker'),
      initialValue: records.projectById(value) == null ? null : value,
      isExpanded: true,
      dropdownColor: AppColors.card,
      decoration: const InputDecoration(labelText: 'Proje (isteğe bağlı)'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Proje yok')),
        for (final p in records.projects)
          DropdownMenuItem(
            value: p.id,
            child: Text(
              [p.name, ?records.customerById(p.customerId)?.name].join(' · '),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const DropdownMenuItem(
          value: _newValue,
          child: Text(
            '＋ Yeni proje oluştur',
            style: TextStyle(color: AppColors.gold),
          ),
        ),
      ],
      onChanged: (id) async {
        if (id != _newValue) {
          onChanged(id);
          return;
        }
        final created = await showProjectEditor(
          context,
          presetCustomerId: customerIdForNew,
        );
        onChanged(created?.id ?? value);
      },
    );
  }
}

class ProjectEditorPage extends StatefulWidget {
  const ProjectEditorPage({super.key, this.existing, this.presetCustomerId});

  final Project? existing;
  final String? presetCustomerId;

  @override
  State<ProjectEditorPage> createState() => _ProjectEditorPageState();
}

class _ProjectEditorPageState extends State<ProjectEditorPage> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _location = TextEditingController(
    text: widget.existing?.location ?? '',
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String? _customerId =
      widget.existing?.customerId ?? widget.presetCustomerId;
  late ProjectStatus _status =
      widget.existing?.status ?? ProjectStatus.preparing;
  late final _initialTexts = [_name.text, _location.text, _note.text];
  late final _initialCustomer = _customerId;
  late final _initialStatus = _status;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initialTexts;
    for (final c in [_name, _location, _note]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    try {
      final saved = await RecordsScope.of(context).saveProject(
        id: widget.existing?.id,
        name: _name.text,
        customerId: _customerId,
        location: _location.text,
        note: _note.text,
        status: _status,
      );
      nav.pop(saved);
    } on CalculationException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dirty =
        _name.text != _initialTexts[0] ||
        _location.text != _initialTexts[1] ||
        _note.text != _initialTexts[2] ||
        _customerId != _initialCustomer ||
        _status != _initialStatus;
    return EditorScaffold(
      title: widget.existing == null ? 'Yeni proje' : 'Projeyi düzenle',
      saveKey: 'proj_save',
      onSave: _save,
      isDirty: dirty,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const ValueKey('proj_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Proje adı * (ör. Yılmaz mutfak)',
            ),
          ),
          const SizedBox(height: 12),
          CustomerPicker(
            fieldKey: 'proj_customer',
            value: _customerId,
            onChanged: (id) => setState(() => _customerId = id),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('proj_location'),
            controller: _location,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Adres veya proje konumu (isteğe bağlı)',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProjectStatus>(
            key: const ValueKey('proj_status'),
            initialValue: _status,
            isExpanded: true,
            dropdownColor: AppColors.card,
            decoration: const InputDecoration(labelText: 'Durum'),
            items: [
              for (final s in ProjectStatus.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (s) => setState(() => _status = s!),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('proj_note'),
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Açıklama (isteğe bağlı)',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                key: const ValueKey('proj_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('proj_save'),
            onPressed: _save,
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
