import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../engine/calculator.dart';
import '../../engine/costing/cost_item.dart';
import '../../engine/money.dart';
import '../../engine/pricing.dart';
import '../../shared/input_parsing.dart';
import '../calculations/widgets/number_field.dart';

/// Maliyet kalemi ekleme/düzenleme sayfasını açar. Kaydedilirse kalemi,
/// vazgeçilirse `null` döner.
Future<CostItem?> showCostItemEditor(
  BuildContext context, {
  required CostItem initial,
  String title = 'Maliyet kalemi',
}) => Navigator.of(context).push<CostItem>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => CostItemEditorPage(initial: initial, title: title),
  ),
);

class CostItemEditorPage extends StatefulWidget {
  const CostItemEditorPage({
    super.key,
    required this.initial,
    this.title = 'Maliyet kalemi',
  });

  final CostItem initial;
  final String title;

  @override
  State<CostItemEditorPage> createState() => _CostItemEditorPageState();
}

class _CostItemEditorPageState extends State<CostItemEditorPage> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _description = TextEditingController(
    text: widget.initial.description,
  );
  late final _quantity = TextEditingController(
    text: decimalToInput(widget.initial.quantity),
  );
  late final _price = TextEditingController(
    text: widget.initial.unitPrice == Money.zero
        ? ''
        : moneyToInput(widget.initial.unitPrice),
  );
  late CostKind _category = widget.initial.category;
  late CostUnit _unit = widget.initial.unit;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _quantity, _price]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _quantity, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Formdaki kalem; geçersizse hata mesajı.
  ({CostItem? item, String? error}) _build() {
    final qty = parseField(_quantity.text);
    final price = parseMoneyField(_price.text);
    if (qty.error != null) return (item: null, error: 'Miktar: ${qty.error}');
    if (price.error != null) {
      return (item: null, error: 'Birim fiyat: ${price.error}');
    }
    if (qty.value == null) return (item: null, error: 'Miktar girin.');
    if (price.value == null) return (item: null, error: 'Birim fiyat girin.');
    final priceChanged = price.value != widget.initial.unitPrice;
    final unitChanged = _unit != widget.initial.unit;
    final item = widget.initial.copyWith(
      name: _name.text.trim(),
      description: _description.text.trim(),
      category: _category,
      quantity: qty.value,
      unit: _unit,
      unitPrice: price.value,
      // Fiyat/birim elle değiştiyse artık fiyat listesindeki kayda bağlı değil.
      clearSource: priceChanged || unitChanged,
    );
    try {
      item.validate();
    } on CalculationException catch (e) {
      return (item: null, error: e.message);
    }
    return (item: item, error: null);
  }

  @override
  Widget build(BuildContext context) {
    final built = _build();
    final item = built.item;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const ValueKey('cost_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(labelText: 'Kalem adı'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('cost_description'),
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Açıklama (isteğe bağlı)',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CostKind>(
            isExpanded: true,
            key: const ValueKey('cost_category'),
            initialValue: _category,
            dropdownColor: AppColors.card,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: [
              for (final k in CostKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (k) => setState(() => _category = k!),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: NumberField(
                  key: const ValueKey('cost_quantity'),
                  controller: _quantity,
                  label: 'Miktar',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<CostUnit>(
                  key: const ValueKey('cost_unit'),
                  initialValue: _unit,
                  isExpanded: true,
                  dropdownColor: AppColors.card,
                  decoration: const InputDecoration(labelText: 'Birim'),
                  items: [
                    for (final u in CostUnit.values)
                      DropdownMenuItem(value: u, child: Text(u.label)),
                  ],
                  onChanged: (u) => setState(() => _unit = u!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          NumberField(
            key: const ValueKey('cost_price'),
            controller: _price,
            label: 'Birim fiyat (₺/${_unit.symbol}, KDV hariç)',
            suffix: '₺',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Toplam',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    item?.total.format() ?? '—',
                    key: const ValueKey('cost_total'),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_submitted && built.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                built.error!,
                key: const ValueKey('cost_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (widget.initial.source != null && item?.source == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Fiyat veya birim değiştirildi; kalem artık fiyat listesindeki '
                'kayda bağlı değil.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('cost_save'),
            onPressed: () {
              setState(() => _submitted = true);
              final result = _build();
              if (result.item != null) Navigator.of(context).pop(result.item);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

/// Boş, kullanıcıya özel kalem.
CostItem blankCostItem(String id) => CostItem(
  id: id,
  name: '',
  category: CostKind.other,
  quantity: Decimal.one,
  unit: CostUnit.piece,
  unitPrice: Money.zero,
);
