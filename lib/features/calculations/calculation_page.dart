import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/trade_category.dart';
import '../../engine/measurement.dart';
import '../../engine/number_format.dart';
import 'calculation_form.dart';
import 'widgets/number_field.dart';
import 'widgets/result_card.dart';

/// Ölçüm ve hesaplama ekranı. Her girişte sonuç anlık olarak yeniden
/// hesaplanır; tüm hesap [evaluateForm] üzerinden motora devredilir.
class CalculationPage extends StatefulWidget {
  const CalculationPage({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  State<CalculationPage> createState() => _CalculationPageState();
}

class _CalculationPageState extends State<CalculationPage> {
  late String _categoryId =
      widget.initialCategoryId ?? TradeCategories.all.first.id;
  late CalcMode _mode = modesForCategory(_categoryId).first;
  LengthUnit _unit = LengthUnit.centimeter;

  late final Map<CalcField, TextEditingController> _controllers = {
    for (final f in CalcField.values)
      f: TextEditingController(
        text: switch (f) {
          CalcField.quantity => '1',
          CalcField.vat => '20',
          _ => '',
        },
      )..addListener(_onChanged),
  };

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TradeCategory get _category =>
      TradeCategories.all.firstWhere((c) => c.id == _categoryId);

  void _selectCategory(String? id) {
    if (id == null) return;
    setState(() {
      _categoryId = id;
      final modes = modesForCategory(id);
      if (!modes.contains(_mode) || _mode == CalcMode.marbleCountertop) {
        _mode = modes.first;
      }
    });
  }

  String? _suffix(CalcField f) => switch (f) {
    CalcField.length || CalcField.width || CalcField.height => _unit.symbol,
    CalcField.waste || CalcField.vat => '%',
    CalcField.quantity => 'adet',
    CalcField.manualAmount => 'birim',
    CalcField.unitPrice ||
    CalcField.materialPrice ||
    CalcField.laborPrice => '₺',
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final evaluation = evaluateForm(
      mode: _mode,
      unit: _unit,
      values: {for (final e in _controllers.entries) e.key: e.value.text},
    );
    final modes = modesForCategory(_categoryId);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(title, style: textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.newCalculation)),
      bottomNavigationBar: _LiveTotalBar(evaluation: evaluation),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            section('Meslek grubu'),
            DropdownButtonFormField<String>(
              key: const ValueKey('category_select'),
              initialValue: _categoryId,
              isExpanded: true,
              dropdownColor: AppColors.card,
              items: [
                for (final c in TradeCategories.all)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: _selectCategory,
            ),
            if (!_category.isAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Bu meslek için özel hesaplar henüz hazır değil. '
                  'Genel hesap türlerini kullanabilirsiniz.',
                  key: const ValueKey('generic_only_note'),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            section('Hesap türü'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in modes)
                  ChoiceChip(
                    key: ValueKey('mode_${m.name}'),
                    label: Text(m.label),
                    selected: m == _mode,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    selectedColor: AppColors.gold,
                    labelStyle: TextStyle(
                      fontSize: 15,
                      color: m == _mode
                          ? AppColors.onGold
                          : AppColors.textPrimary,
                    ),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _mode = m),
                  ),
              ],
            ),
            if (_mode == CalcMode.marbleCountertop)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Malzeme fireli m² üzerinden, işçilik metre tül '
                  '(tezgâh uzunluğu) üzerinden hesaplanır.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (_mode.usesLengthUnit) ...[
              section('Ölçü birimi'),
              SegmentedButton<LengthUnit>(
                key: const ValueKey('unit_select'),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  selectedBackgroundColor: AppColors.gold,
                  selectedForegroundColor: AppColors.onGold,
                ),
                segments: [
                  for (final u in LengthUnit.values)
                    ButtonSegment(
                      value: u,
                      label: Text(u.symbol, key: ValueKey('unit_${u.name}')),
                    ),
                ],
                selected: {_unit},
                onSelectionChanged: (s) => setState(() => _unit = s.first),
              ),
            ],
            section('Ölçüler ve fiyat'),
            for (final f in _mode.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NumberField(
                  key: ValueKey('field_${f.name}'),
                  controller: _controllers[f]!,
                  label: _mode.fieldLabel(f),
                  suffix: _suffix(f),
                  errorText: evaluation.fieldErrors[f],
                  integerOnly: f == CalcField.quantity,
                ),
              ),
            const SizedBox(height: 8),
            if (evaluation.result case final result?)
              ResultCard(result: result)
            else
              Card(
                key: const ValueKey('result_placeholder'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.gold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          evaluation.message ?? 'Ölçüleri girin.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ekranın altında sabit duran, her girişte güncellenen özet çubuğu.
/// Tek elle kullanımda sonuç için aşağı kaydırmak gerekmez.
class _LiveTotalBar extends StatelessWidget {
  const _LiveTotalBar({required this.evaluation});

  final FormEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final result = evaluation.result;
    final String label;
    final String value;
    if (result == null) {
      label = evaluation.message ?? 'Ölçüleri girin.';
      value = '';
    } else if (result.price case final price?) {
      label = 'Genel toplam';
      value = price.grandTotal.format();
    } else {
      final main = result.figures.firstWhere(
        (f) => f.highlighted,
        orElse: () => result.figures.first,
      );
      label = main.label;
      value = formatQuantity(main.value, main.unit);
    }

    return Container(
      key: const ValueKey('live_total'),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
              if (value.isNotEmpty)
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
