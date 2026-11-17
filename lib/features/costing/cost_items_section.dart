import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../data/catalog_scope.dart';
import '../../engine/costing/cost_item.dart';
import '../../engine/costing/cost_sheet.dart';
import '../../engine/costing/price_list.dart';
import '../../engine/number_format.dart';
import 'cost_item_editor.dart';

/// Ek maliyet kalemleri bölümü: listele, ekle (boş / hazır şablon / fiyat
/// listesinden), düzenle, kopyala, sil, fiyat listesine kaydet.
///
/// Her meslek ekranı kendi [templates] listesini verir.
class CostItemsSection extends StatelessWidget {
  const CostItemsSection({
    super.key,
    required this.sheet,
    required this.onChanged,
    this.templates = const [],
  });

  final CostSheet sheet;
  final ValueChanged<CostSheet> onChanged;
  final List<CostTemplate> templates;

  Future<void> _add(BuildContext context) async {
    final catalog = CatalogScope.of(context);
    final choice = await showModalBottomSheet<_AddChoice>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      builder: (_) =>
          _AddMenu(templates: templates, priceItems: catalog.priceList.items),
    );
    if (choice == null || !context.mounted) return;
    final id = catalog.ids.next();
    final initial = switch (choice) {
      _BlankChoice() => blankCostItem(id),
      _TemplateChoice(:final template) => template.toItem(id: id),
      _PriceListChoice(:final item) => item.toCostItem(id: id),
    };
    final item = await showCostItemEditor(
      context,
      initial: initial,
      title: 'Kalem ekle',
    );
    if (item != null) onChanged(sheet.add(item));
  }

  Future<void> _edit(BuildContext context, CostItem item) async {
    final edited = await showCostItemEditor(
      context,
      initial: item,
      title: 'Kalemi düzenle',
    );
    if (edited != null) onChanged(sheet.update(edited));
  }

  Future<void> _saveToList(BuildContext context, CostItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    await CatalogScope.of(context).saveCostItemToList(item);
    messenger.showSnackBar(
      SnackBar(content: Text('"${item.name}" fiyat listesine kaydedildi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = CatalogScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in sheet.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              key: ValueKey('cost_item_${item.id}'),
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 16, right: 4),
                title: Text(item.name),
                subtitle: Text(
                  '${item.category.label} · '
                  '${formatQuantity(item.quantity, item.unit.symbol)} × '
                  '${item.unitPrice.format()}'
                  '${item.description.isEmpty ? '' : '\n${item.description}'}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                onTap: () => _edit(context, item),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.total.format(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    PopupMenuButton<String>(
                      key: ValueKey('cost_menu_${item.id}'),
                      color: AppColors.card,
                      onSelected: (action) {
                        switch (action) {
                          case 'edit':
                            _edit(context, item);
                          case 'copy':
                            onChanged(
                              sheet.duplicate(
                                item.id,
                                newId: catalog.ids.next(),
                              ),
                            );
                          case 'save':
                            _saveToList(context, item);
                          case 'delete':
                            onChanged(sheet.remove(item.id));
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                        PopupMenuItem(value: 'copy', child: Text('Kopyala')),
                        PopupMenuItem(
                          value: 'save',
                          child: Text('Fiyat listesine kaydet'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Sil')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (sheet.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 16),
            child: Text(
              'Ek kalemler toplamı: ${sheet.subtotal.format()}',
              key: const ValueKey('extras_total'),
              textAlign: TextAlign.end,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        OutlinedButton.icon(
          key: const ValueKey('add_cost_item'),
          onPressed: () => _add(context),
          icon: const Icon(Icons.add),
          label: const Text('Ek maliyet ekle'),
        ),
      ],
    );
  }
}

sealed class _AddChoice {
  const _AddChoice();
}

final class _BlankChoice extends _AddChoice {
  const _BlankChoice();
}

final class _TemplateChoice extends _AddChoice {
  const _TemplateChoice(this.template);
  final CostTemplate template;
}

final class _PriceListChoice extends _AddChoice {
  const _PriceListChoice(this.item);
  final PriceListItem item;
}

class _AddMenu extends StatelessWidget {
  const _AddMenu({required this.templates, required this.priceItems});

  final List<CostTemplate> templates;
  final List<PriceListItem> priceItems;

  @override
  Widget build(BuildContext context) {
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        children: [
          ListTile(
            key: const ValueKey('add_blank'),
            leading: const Icon(Icons.edit_note),
            title: const Text('Kendi kalemimi oluştur'),
            onTap: () => Navigator.pop(context, const _BlankChoice()),
          ),
          if (templates.isNotEmpty) header('Hazır kalemler'),
          for (final t in templates)
            ListTile(
              key: ValueKey('add_template_${t.name}'),
              leading: const Icon(Icons.add_circle_outline),
              title: Text(t.name),
              subtitle: Text(
                '${t.category.label} · ${t.unit.label}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () => Navigator.pop(context, _TemplateChoice(t)),
            ),
          header('Fiyat listesinden'),
          if (priceItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Fiyat listeniz boş. Ayarlar → Fiyat Listesi bölümünden '
                'ekleyebilir veya bir kalemi "Fiyat listesine kaydet" ile '
                'kaydedebilirsiniz.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          for (final p in priceItems)
            ListTile(
              key: ValueKey('add_price_${p.id}'),
              leading: const Icon(Icons.sell_outlined),
              title: Text(p.name),
              subtitle: Text(
                '${p.category.label} · ${p.price.format()}/${p.unit.symbol}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () => Navigator.pop(context, _PriceListChoice(p)),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
