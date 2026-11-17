import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/catalog_scope.dart';
import '../../../engine/calculation_result.dart';
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
import 'recipe_pages.dart';

/// PVC kapı ve pencere doğrama projesi.
class PvcProjectPage extends StatefulWidget {
  const PvcProjectPage({super.key});

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

  @override
  void initState() {
    super.initState();
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

  Future<void> _edit(JoineryItem? existing) async {
    final catalog = CatalogScope.of(context);
    final item = await showJoineryItemEditor(
      context,
      unit: _unit,
      recipes: catalog.recipes,
      initial:
          existing ??
          JoineryItem(id: catalog.ids.next(), type: JoineryType.window),
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
    final profileWaste = parseField(_profileWaste.text);
    final glassWaste = parseField(_glassWaste.text);
    CalculationResult? result;
    String? message;
    final fieldError = profileWaste.error ?? glassWaste.error ?? _pricing.error;
    if (fieldError != null) {
      message = 'Hatalı alanları düzeltin.';
    } else {
      try {
        result = const PvcJoineryCalculator().calculate(
          PvcProjectInput(
            items: _withFreshRecipes(catalog.recipes),
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
        title: const Text('PVC doğrama projesi'),
        actions: [
          TextButton.icon(
            key: const ValueKey('open_recipes'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RecipeListPage()),
            ),
            icon: const Icon(Icons.rule_folder_outlined),
            label: const Text('Profil reçeteleri'),
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
            const SectionTitle(
              'Doğrama kalemleri',
              subtitle:
                  'Pencere, kapı ve balkon kapısı; her kalem ayrı ölçü, '
                  'adet, cam, profil ve aksesuar taşır.',
            ),
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  key: ValueKey('joinery_${item.id}'),
                  child: ListTile(
                    contentPadding: const EdgeInsets.only(left: 16, right: 4),
                    title: Text(item.labelAt(_items.indexOf(item))),
                    subtitle: Text(
                      _summary(item),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    onTap: () => _edit(item),
                    trailing: ItemActionsMenu(
                      key: ValueKey('joinery_menu_${item.id}'),
                      onEdit: () => _edit(item),
                      onCopy: () => _copy(item),
                      onDelete: () => setState(
                        () => _items = [
                          for (final x in _items)
                            if (x.id != item.id) x,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            OutlinedButton.icon(
              key: const ValueKey('add_joinery'),
              onPressed: () => _edit(null),
              icon: const Icon(Icons.add),
              label: const Text('Doğrama ekle'),
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
