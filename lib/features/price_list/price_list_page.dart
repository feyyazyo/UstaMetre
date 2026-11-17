import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../data/catalog_scope.dart';
import '../../engine/calculator.dart';
import '../../engine/costing/cost_item.dart';
import '../../engine/costing/price_list.dart';
import '../../engine/pricing.dart';
import '../../shared/input_parsing.dart';
import '../calculations/widgets/number_field.dart';

String _date(DateTime d) {
  final l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year}';
}

/// Fiyat listesi: malzeme, işçilik, aksesuar, nakliye ve diğer kalemler.
class PriceListPage extends StatelessWidget {
  const PriceListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = CatalogScope.of(context);
    final list = catalog.priceList;
    return Scaffold(
      appBar: AppBar(title: const Text('Fiyat Listesi')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add_price_item'),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.onGold,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PriceItemEditorPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Kalem ekle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const Text(
            'Fiyatlar KDV hariçtir. Bir fiyatı değiştirdiğinizde eski fiyat '
            'geçmişte saklanır; daha önce yapılmış hesaplardaki kalemler '
            'kendi fiyatlarını korur.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          if (list.items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Text(
                'Fiyat listeniz boş.',
                key: ValueKey('price_list_empty'),
                textAlign: TextAlign.center,
              ),
            ),
          for (final kind in CostKind.values)
            if (list.byCategory(kind).isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  kind.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final item in list.byCategory(kind))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    key: ValueKey('price_item_${item.id}'),
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.history.length} fiyat kaydı · '
                        'son: ${_date(item.current.effectiveFrom)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: Text(
                        '${item.price.format()}/${item.unit.symbol}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PriceItemEditorPage(item: item),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

/// Fiyat listesi kaydı ekleme/düzenleme ve fiyat geçmişi.
class PriceItemEditorPage extends StatefulWidget {
  const PriceItemEditorPage({super.key, this.item});

  /// `null` ise yeni kayıt.
  final PriceListItem? item;

  @override
  State<PriceItemEditorPage> createState() => _PriceItemEditorPageState();
}

class _PriceItemEditorPageState extends State<PriceItemEditorPage> {
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _description = TextEditingController(
    text: widget.item?.description ?? '',
  );
  late final _price = TextEditingController(
    text: moneyToInput(widget.item?.price),
  );
  late CostKind _category = widget.item?.category ?? CostKind.material;
  late CostUnit _unit = widget.item?.unit ?? CostUnit.piece;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final catalog = CatalogScope.of(context);
    final nav = Navigator.of(context);
    final price = parseMoneyField(_price.text);
    if (price.error != null || price.value == null) {
      setState(() => _error = price.error ?? 'Fiyat girin.');
      return;
    }
    try {
      final item = widget.item;
      if (item == null) {
        await catalog.addPriceItem(
          name: _name.text,
          category: _category,
          unit: _unit,
          price: price.value!,
          description: _description.text.trim(),
        );
      } else {
        await catalog.updatePriceItem(
          item.id,
          name: _name.text,
          description: _description.text.trim(),
          category: _category,
          price: price.value,
          unit: _unit,
        );
      }
      nav.pop();
    } on CalculationException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(item == null ? 'Fiyat ekle' : 'Fiyatı düzenle'),
        actions: [
          if (item != null)
            IconButton(
              key: const ValueKey('delete_price_item'),
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final nav = Navigator.of(context);
                await CatalogScope.of(context).removePriceItem(item.id);
                nav.pop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const ValueKey('price_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Kalem adı'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('price_description'),
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Açıklama (isteğe bağlı)',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CostKind>(
            isExpanded: true,
            key: const ValueKey('price_category'),
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
          DropdownButtonFormField<CostUnit>(
            isExpanded: true,
            key: const ValueKey('price_unit'),
            initialValue: _unit,
            dropdownColor: AppColors.card,
            decoration: const InputDecoration(labelText: 'Birim'),
            items: [
              for (final u in CostUnit.values)
                DropdownMenuItem(value: u, child: Text(u.label)),
            ],
            onChanged: (u) => setState(() => _unit = u!),
          ),
          const SizedBox(height: 12),
          NumberField(
            key: const ValueKey('price_value'),
            controller: _price,
            label: 'Fiyat (₺/${_unit.symbol}, KDV hariç)',
            suffix: '₺',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                key: const ValueKey('price_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('price_save'),
            onPressed: _save,
            child: const Text('Kaydet'),
          ),
          if (item != null) ...[
            const SizedBox(height: 24),
            Text(
              'Fiyat geçmişi',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final p in item.history.reversed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history, size: 20),
                title: Text('${p.price.format()}/${p.unit.symbol}'),
                trailing: Text(
                  _date(p.effectiveFrom),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
