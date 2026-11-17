import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/trade_category.dart';
import '../../engine/calculators/marble_project_calculator.dart';
import '../../engine/calculators/pvc_joinery_calculator.dart';
import '../../engine/costing/cost_item.dart';
import '../../engine/costing/cost_sheet.dart';
import '../../engine/measurement.dart';
import '../costing/cost_items_section.dart';
import '../costing/pricing_options.dart';
import 'calculation_form.dart';
import 'category_hub_page.dart';
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
          _ => '',
        },
      )..addListener(_onChanged),
  };

  final _pricing = PricingOptionsController();
  CostSheet _extras = const CostSheet();

  void _onChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _pricing.addListener(_onChanged);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _pricing.dispose();
    super.dispose();
  }

  List<CostTemplate> get _templates => switch (_categoryId) {
    'marble_granite' => MarbleCatalog.extras,
    'pvc_joinery' => PvcCatalog.extras,
    _ => const [],
  };

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
      values: {
        for (final e in _controllers.entries) e.key: e.value.text,
        CalcField.vat: _pricing.vat.text,
      },
      extras: _extras,
      discount: _pricing.discount.value,
    );
    final pricingError = _pricing.error;
    final result = pricingError == null ? evaluation.result : null;
    final message = pricingError == null
        ? evaluation.message
        : 'Fiyatlandırma: $pricingError';
    final modes = modesForCategory(_categoryId);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(title, style: textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.newCalculation)),
      bottomNavigationBar: LiveTotalBar(result: result, message: message),
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
            if (CategoryHubPage.projectPageFor(_categoryId) != null)
              _ProjectBanner(categoryId: _categoryId),
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
            section('Ek maliyetler'),
            CostItemsSection(
              key: const ValueKey('extras_section'),
              sheet: _extras,
              templates: _templates,
              onChanged: (sheet) => setState(() => _extras = sheet),
            ),
            section('Fiyatlandırma'),
            PricingOptionsSection(controller: _pricing),
            const SizedBox(height: 20),
            if (result != null)
              ResultCard(result: result, display: _pricing.display)
            else
              ResultPlaceholder(message: message ?? 'Ölçüleri girin.'),
          ],
        ),
      ),
    );
  }
}

/// Hızlı hesapta, özel proje ekranı olan kategoriler için belirgin yönlendirme.
/// Çok parçalı tezgâh ve PVC doğrama türleri yalnızca proje ekranlarındadır.
class _ProjectBanner extends StatelessWidget {
  const _ProjectBanner({required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, icon) = switch (categoryId) {
      'marble_granite' => (
        'Çok parçalı tezgâh projesi',
        'Birden fazla parça, sakal/pah/rodaj, evye, ocak, montaj',
        Icons.view_quilt_outlined,
      ),
      _ => (
        'PVC doğrama projesi',
        'Pencere · Kapı · Balkon kapısı — cam, profil, aksesuar',
        Icons.window_outlined,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: AppColors.gold.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.gold),
        ),
        child: InkWell(
          key: const ValueKey('open_project'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CategoryHubPage.projectPageFor(categoryId)!,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.gold, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.gold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
