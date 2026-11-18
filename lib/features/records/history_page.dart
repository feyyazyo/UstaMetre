import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../data/records_controller.dart';
import '../../domain/records/saved_calculation.dart';
import '../../domain/trade_category.dart';
import '../calculations/calculations_page.dart';
import 'calculation_tile.dart';
import 'record_widgets.dart';

/// Hesap geçmişi: arama, meslek filtresi, tarih sıralaması.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _search = TextEditingController();
  String? _categoryId;
  bool _newestFirst = true;

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

  List<SavedCalculation> _filter(List<SavedCalculation> all) {
    final q = _search.text.trim().toLowerCase();
    final list = all
        .where(
          (c) =>
              (q.isEmpty || c.name.toLowerCase().contains(q)) &&
              (_categoryId == null || c.categoryId == _categoryId),
        )
        .toList();
    list.sort(
      (a, b) => _newestFirst
          ? b.updatedAt.compareTo(a.updatedAt)
          : a.updatedAt.compareTo(b.updatedAt),
    );
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final records = RecordsScope.of(context);
    final all = records.calculations;
    final list = _filter(all);
    final usedCategories = {for (final c in all) c.categoryId};

    return Scaffold(
      appBar: AppBar(title: Text('Hesap Geçmişi (${all.length})')),
      body: !records.isAvailable
          ? RecordsUnavailable(error: records.error)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (records.corrupt.isNotEmpty)
                  Card(
                    key: const ValueKey('corrupt_warning'),
                    color: AppColors.gold.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${records.corrupt.length} kayıt okunamadı. Bu kayıtlar '
                        'silinmedi; cihazda ve yedekte korunuyor.',
                      ),
                    ),
                  ),
                TextField(
                  key: const ValueKey('history_search'),
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: 'Hesap adına göre ara',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Temizle',
                            icon: const Icon(Icons.clear),
                            onPressed: _search.clear,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: const ValueKey('history_category'),
                        initialValue: _categoryId,
                        isExpanded: true,
                        dropdownColor: AppColors.card,
                        decoration: const InputDecoration(labelText: 'Meslek'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tümü'),
                          ),
                          for (final c in TradeCategories.all)
                            if (usedCategories.contains(c.id))
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                        ],
                        onChanged: (id) => setState(() => _categoryId = id),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('history_sort'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                      onPressed: () =>
                          setState(() => _newestFirst = !_newestFirst),
                      icon: Icon(
                        _newestFirst
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                      ),
                      label: Text(_newestFirst ? 'En yeni' : 'En eski'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (all.isEmpty)
                  EmptyHint(
                    key: const ValueKey('history_empty'),
                    icon: Icons.history,
                    title: 'Henüz kayıtlı hesap yok',
                    message:
                        'Bir hesap yapın ve ekranın sağ üstündeki "Kaydet" '
                        'butonuyla saklayın. Kayıtlı hesaplar burada listelenir.',
                    action: FilledButton.icon(
                      key: const ValueKey('history_new'),
                      onPressed: () =>
                          CalculationsPage.openCalculation(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Yeni hesap'),
                    ),
                  )
                else if (list.isEmpty)
                  const EmptyHint(
                    key: ValueKey('history_no_match'),
                    icon: Icons.search_off,
                    title: 'Uygun hesap bulunamadı',
                    message: 'Aramayı veya meslek filtresini değiştirin.',
                  )
                else
                  for (final c in list) CalculationTile(calc: c),
              ],
            ),
    );
  }
}
