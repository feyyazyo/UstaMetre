import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/catalog_scope.dart';
import '../../../domain/records/saved_calculation.dart';
import '../../../engine/calculation_result.dart';
import '../../records/save_calculation_page.dart';
import '../../../engine/calculator.dart';
import '../../../engine/calculators/pvc_joinery_calculator.dart';
import '../../../engine/costing/cost_sheet.dart';
import '../../../engine/measurement.dart';
import '../../../engine/number_format.dart';
import '../../../shared/input_parsing.dart';
import '../../costing/cost_items_section.dart';
import '../../costing/pricing_options.dart';
import '../widgets/number_field.dart';
import '../widgets/project_scaffold.dart';
import '../widgets/result_card.dart';
import 'joinery_item_editor_page.dart';
import 'joinery_type_picker.dart';
import 'recipe_pages.dart';

/// PVC kapı ve pencere doğrama projesi.
class PvcProjectPage extends StatefulWidget {
  const PvcProjectPage({super.key, this.editing, this.presetProjectId});

  /// Kayıtlı hesabı düzenlemek için açıldıysa o hesap.
  final SavedCalculation? editing;
  final String? presetProjectId;

  @override
  State<PvcProjectPage> createState() => _PvcProjectPageState();
}

class _PvcProjectPageState extends State<PvcProjectPage> {
  LengthUnit _unit = LengthUnit.centimeter;
  List<JoineryItem> _items = const [];
  CostSheet _extras = const CostSheet();
  final _pricing = PricingOptionsController();
  final _profileWaste = TextEditingController();
  final _glassWaste = TextEditingController();

  late SavedCalculation? _editing = widget.editing;

  void _restore(Map<String, Object?> inputs) {
    _unit =
        LengthUnit.values.where((u) => u.name == inputs['unit']).firstOrNull ??
        _unit;
    _items = [
      for (final i in (inputs['items'] as List?) ?? const [])
        JoineryItem.fromJson((i! as Map).cast<String, Object?>()),
    ];
    final fields = (inputs['fields'] as Map?) ?? const {};
    if (fields['profileWaste'] case final String t) _profileWaste.text = t;
    if (fields['glassWaste'] case final String t) _glassWaste.text = t;
    _pricing.restore((inputs['pricing'] as Map?)?.cast<String, Object?>());
    _extras = CostSheet.fromJson((inputs['extras'] as List?) ?? const []);
  }

  /// Hesapta kullanılan kalemler (reçete kopyaları dahil) saklanır.
  CalcRevision _revision(CalculationResult result, List<JoineryItem> used) =>
      CalcRevision(
        number: 1,
        savedAt: DateTime.now(),
        categoryId: 'pvc_joinery',
        kind: CalcKind.pvcProject,
        modeLabel: 'Doğrama projesi (${used.length} kalem)',
        inputs: {
          'unit': _unit.name,
          'items': [for (final i in used) i.toJson()],
          'fields': {
            'profileWaste': _profileWaste.text,
            'glassWaste': _glassWaste.text,
          },
          'pricing': _pricing.toJson(),
          'extras': _extras.toJson(),
        },
        result: result,
      );

  Future<void> _save(CalculationResult? result, List<JoineryItem> used) async {
    final saved = await saveFromCalculator(
      context,
      revision: result == null ? null : _revision(result, used),
      existing: _editing,
      presetProjectId: widget.presetProjectId,
    );
    if (saved != null && mounted) setState(() => _editing = saved);
  }

  @override
  void initState() {
    super.initState();
    if (widget.editing case final saved?) _restore(saved.current.inputs);
    _profileWaste.addListener(_changed);
    _glassWaste.addListener(_changed);
    _pricing.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _profileWaste.dispose();
    _glassWaste.dispose();
    _pricing.dispose();
    super.dispose();
  }

  /// Reçete kalemde kopya olarak tutulur; ekranda düzenlenen reçetenin en
  /// güncel hâli kullanılsın diye katalogdan tazelenir.
  List<JoineryItem> _withFreshRecipes(List<ProfileRecipe> recipes) => [
    for (final item in _items)
      switch (item.profile) {
        RecipeProfile(:final recipe)
            when recipes.any((r) => r.id == recipe.id) =>
          item.copyWith(
            profile: RecipeProfile(
              recipes.firstWhere((r) => r.id == recipe.id),
            ),
          ),
        _ => item,
      },
  ];

  Future<void> _edit(
    JoineryItem? existing, {
    JoineryType type = JoineryType.window,
  }) async {
    final catalog = CatalogScope.of(context);
    final item = await showJoineryItemEditor(
      context,
      unit: _unit,
      recipes: catalog.recipes,
      initial: existing ?? JoineryItem(id: catalog.ids.next(), type: type),
    );
    if (item == null) return;
    setState(() {
      _items = existing == null
          ? [..._items, item]
          : [for (final i in _items) i.id == item.id ? item : i];
    });
  }

  void _copy(JoineryItem item) {
    final copy = JoineryItem(
      id: CatalogScope.of(context).ids.next(),
      type: item.type,
      name: item.name.isEmpty ? '' : '${item.name} (kopya)',
      width: item.width,
      height: item.height,
      quantity: item.quantity,
      glassType: item.glassType,
      glassPricePerSquareMeter: item.glassPricePerSquareMeter,
      glassAreaPerUnit: item.glassAreaPerUnit,
      profile: item.profile,
      accessoryPricePerUnit: item.accessoryPricePerUnit,
      flyScreen: item.flyScreen,
      flyScreenPricePerUnit: item.flyScreenPricePerUnit,
    );
    final i = _items.indexWhere((x) => x.id == item.id);
    setState(() => _items = [..._items]..insert(i + 1, copy));
  }

  void _delete(JoineryItem item) {
    final index = _items.indexWhere((x) => x.id == item.id);
    final label = joineryLabels(_items)[index];
    setState(
      () => _items = [
        for (final x in _items)
          if (x.id != item.id) x,
      ],
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"$label" silindi.'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () => setState(
              () =>
                  _items = [..._items]
                    ..insert(index.clamp(0, _items.length), item),
            ),
          ),
        ),
      );
  }

  String _summary(JoineryItem item) {
    final parts = <String>[
      '${formatDecimal(item.width!)} × ${formatDecimal(item.height!)} '
          '${_unit.symbol}${item.quantity > 1 ? ' × ${item.quantity} adet' : ''}',
      if (item.glassType.isNotEmpty) item.glassType,
      switch (item.profile) {
        null => 'Profil yok',
        ManualProfile() => 'Profil: manuel',
        RecipeProfile(:final recipe) =>
          'Profil: ${recipe.name}${recipe.verified ? '' : ' (tahmini)'}',
      },
      if (item.flyScreen) 'Sineklik',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = CatalogScope.of(context);
    final labels = joineryLabels(_items);
    final profileWaste = parseField(_profileWaste.text);
    final glassWaste = parseField(_glassWaste.text);
    CalculationResult? result;
    String? message;
    final used = _withFreshRecipes(catalog.recipes);
    final fieldError = profileWaste.error ?? glassWaste.error ?? _pricing.error;
    if (fieldError != null) {
      message = 'Hatalı alanları düzeltin.';
    } else {
      try {
        result = const PvcJoineryCalculator().calculate(
          PvcProjectInput(
            items: used,
            unit: _unit,
            profileWastePercent: profileWaste.value,
            glassWastePercent: glassWaste.value,
            extras: _extras,
            vatPercent: _pricing.vatPercent.value,
            discount: _pricing.discount.value,
          ),
        );
      } on CalculationException catch (e) {
        message = e.message;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing?.name ?? 'PVC doğrama',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            key: const ValueKey('open_recipes'),
            tooltip: 'Profil reçeteleri',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RecipeListPage()),
            ),
            icon: const Icon(Icons.rule_folder_outlined),
          ),
          SaveCalculationAction(
            enabled: result != null,
            onPressed: () => _save(result, used),
          ),
        ],
      ),
      bottomNavigationBar: LiveTotalBar(result: result, message: message),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const SectionTitle('Ölçü birimi'),
            LengthUnitSelector(
              value: _unit,
              onChanged: (u) => setState(() => _unit = u),
            ),
            SectionTitle(
              'Doğrama kalemleri (${_items.length})',
              subtitle:
                  'Pencere, kapı ve balkon kapısı; her kalem ayrı ölçü, '
                  'adet, cam, profil ve aksesuar taşır.',
            ),
            for (final (index, item) in _items.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  key: ValueKey('joinery_${item.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        leading: Icon(joineryIcon(item.type), size: 30),
                        title: Text(labels[index]),
                        subtitle: Text(
                          _summary(item),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onTap: () => _edit(item),
                      ),
                      ItemActionsRow(
                        keyPrefix: 'joinery_${item.id}',
                        onEdit: () => _edit(item),
                        onCopy: () => _copy(item),
                        onDelete: () => _delete(item),
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              _items.isEmpty ? 'İlk doğramayı ekleyin:' : 'Yeni doğrama ekle:',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final t in JoineryType.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  key: ValueKey('add_${t.name}'),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => _edit(null, type: t),
                  icon: Icon(joineryIcon(t)),
                  label: Text('${t.label} ekle'),
                ),
              ),
            const SectionTitle(
              'Fire',
              subtitle:
                  'Profil firesi yalnızca profil metrajına, cam firesi '
                  'yalnızca cam alanına uygulanır.',
            ),
            NumberField(
              key: const ValueKey('field_profileWaste'),
              controller: _profileWaste,
              label: 'Profil firesi',
              suffix: '%',
              errorText: profileWaste.error,
            ),
            const SizedBox(height: 12),
            NumberField(
              key: const ValueKey('field_glassWaste'),
              controller: _glassWaste,
              label: 'Cam firesi',
              suffix: '%',
              errorText: glassWaste.error,
            ),
            const SectionTitle(
              'Ek kalemler',
              subtitle: 'Montaj, nakliye, söküm ve diğer kalemler.',
            ),
            CostItemsSection(
              sheet: _extras,
              templates: PvcCatalog.extras,
              onChanged: (s) => setState(() => _extras = s),
            ),
            const SectionTitle('Fiyatlandırma'),
            PricingOptionsSection(controller: _pricing),
            const SizedBox(height: 20),
            if (result != null)
              ResultCard(result: result, display: _pricing.display)
            else
              ResultPlaceholder(message: message ?? ''),
          ],
        ),
      ),
    );
  }
}
