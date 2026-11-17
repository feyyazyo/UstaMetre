import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../engine/calculators/pvc_joinery_calculator.dart';
import '../../../engine/measurement.dart';
import '../../../shared/input_parsing.dart';
import '../widgets/number_field.dart';
import '../widgets/project_scaffold.dart';
import 'joinery_type_picker.dart';

enum _ProfileMode {
  none('Profil yok'),
  manual('Manuel metraj'),
  recipe('Profil reçetesi');

  const _ProfileMode(this.label);

  final String label;
}

Future<JoineryItem?> showJoineryItemEditor(
  BuildContext context, {
  required JoineryItem initial,
  required LengthUnit unit,
  required List<ProfileRecipe> recipes,
}) => Navigator.of(context).push<JoineryItem>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) =>
        JoineryItemEditorPage(initial: initial, unit: unit, recipes: recipes),
  ),
);

class JoineryItemEditorPage extends StatefulWidget {
  const JoineryItemEditorPage({
    super.key,
    required this.initial,
    required this.unit,
    required this.recipes,
  });

  final JoineryItem initial;
  final LengthUnit unit;
  final List<ProfileRecipe> recipes;

  @override
  State<JoineryItemEditorPage> createState() => _JoineryItemEditorPageState();
}

class _JoineryItemEditorPageState extends State<JoineryItemEditorPage> {
  JoineryItem get _i => widget.initial;
  late JoineryType _type = _i.type;
  late final _name = TextEditingController(text: _i.name);
  late final _width = TextEditingController(text: decimalToInput(_i.width));
  late final _height = TextEditingController(text: decimalToInput(_i.height));
  late final _quantity = TextEditingController(text: '${_i.quantity}');
  late final _glassType = TextEditingController(text: _i.glassType);
  late final _glassPrice = TextEditingController(
    text: moneyToInput(_i.glassPricePerSquareMeter),
  );
  late final _glassArea = TextEditingController(
    text: decimalToInput(_i.glassAreaPerUnit),
  );
  late _ProfileMode _profileMode = switch (_i.profile) {
    null => _ProfileMode.none,
    ManualProfile() => _ProfileMode.manual,
    RecipeProfile() => _ProfileMode.recipe,
  };
  late final _profileMeters = TextEditingController(
    text: _i.profile is ManualProfile
        ? decimalToInput((_i.profile! as ManualProfile).metersPerUnit)
        : '',
  );
  late final _profilePrice = TextEditingController(
    text: _i.profile is ManualProfile
        ? moneyToInput((_i.profile! as ManualProfile).pricePerMeter)
        : '',
  );

  /// Seçilebilir reçeteler. Kalemin kendi reçetesi katalogdan silinmişse
  /// kayıtlı kopyası "(silinmiş)" olarak listede kalır.
  late final List<ProfileRecipe> _recipes = [
    ...widget.recipes,
    if (_i.profile case RecipeProfile(:final recipe)
        when !widget.recipes.any((r) => r.id == recipe.id))
      recipe,
  ];

  bool _isDeleted(ProfileRecipe r) => !widget.recipes.any((x) => x.id == r.id);

  late String? _recipeId = switch (_i.profile) {
    RecipeProfile(:final recipe) => recipe.id,
    _ => _recipes.isEmpty ? null : _recipes.first.id,
  };
  late final _accessory = TextEditingController(
    text: moneyToInput(_i.accessoryPricePerUnit),
  );
  late bool _flyScreen = _i.flyScreen;
  late final _flyScreenPrice = TextEditingController(
    text: moneyToInput(_i.flyScreenPricePerUnit),
  );
  bool _submitted = false;

  List<TextEditingController> get _all => [
    _name,
    _width,
    _height,
    _quantity,
    _glassType,
    _glassPrice,
    _glassArea,
    _profileMeters,
    _profilePrice,
    _accessory,
    _flyScreenPrice,
  ];

  late final _initialProfileMode = _profileMode;
  late final _initialRecipeId = _recipeId;
  late final List<(TextEditingController, String)> _initialTexts = [
    for (final c in _all) (c, c.text),
  ];

  @override
  void initState() {
    super.initState();
    _initialTexts; // başlangıç değerlerini sabitle
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

  ({JoineryItem? item, Map<String, String> errors}) _build() {
    final errors = <String, String>{};
    T? take<T>(String key, ParsedField<T> f, {bool needed = false}) {
      if (f.error != null) {
        errors[key] = f.error!;
      } else if (needed && f.value == null && _submitted) {
        errors[key] = 'Bu alan gerekli';
      }
      return f.value;
    }

    final width = take('width', parseField(_width.text), needed: true);
    final height = take('height', parseField(_height.text), needed: true);
    final quantity = take('quantity', parseCountField(_quantity.text));
    final glassPrice = take('glassPrice', parseMoneyField(_glassPrice.text));
    final glassArea = take('glassArea', parseField(_glassArea.text));
    final accessory = take('accessory', parseMoneyField(_accessory.text));
    final flyPrice = take(
      'flyScreenPrice',
      parseMoneyField(_flyScreenPrice.text),
    );

    ProfileSpec? profile;
    switch (_profileMode) {
      case _ProfileMode.none:
        break;
      case _ProfileMode.manual:
        final meters = take(
          'profileMeters',
          parseField(_profileMeters.text),
          needed: true,
        );
        final price = take(
          'profilePrice',
          parseMoneyField(_profilePrice.text),
          needed: true,
        );
        if (meters != null && price != null) {
          profile = ManualProfile(metersPerUnit: meters, pricePerMeter: price);
        }
      case _ProfileMode.recipe:
        final recipe = _recipes.where((r) => r.id == _recipeId).firstOrNull;
        if (recipe == null) {
          if (_submitted) errors['recipe'] = 'Bir reçete seçin';
        } else {
          profile = RecipeProfile(recipe);
        }
    }

    if (errors.isNotEmpty ||
        width == null ||
        height == null ||
        quantity == null) {
      return (item: null, errors: errors);
    }
    if (_profileMode != _ProfileMode.none && profile == null) {
      return (item: null, errors: errors);
    }
    return (
      item: JoineryItem(
        id: _i.id,
        type: _type,
        name: _name.text.trim(),
        width: width,
        height: height,
        quantity: quantity,
        glassType: _glassType.text.trim(),
        glassPricePerSquareMeter: glassPrice,
        glassAreaPerUnit: glassArea,
        profile: profile,
        accessoryPricePerUnit: accessory,
        flyScreen: _flyScreen,
        flyScreenPricePerUnit: flyPrice,
      ),
      errors: errors,
    );
  }

  static const _fieldNames = {
    'width': 'En',
    'height': 'Boy',
    'quantity': 'Adet',
    'glassPrice': 'Cam fiyatı',
    'glassArea': 'Cam alanı',
    'profileMeters': 'Profil metrajı',
    'profilePrice': 'Profil fiyatı',
    'recipe': 'Reçete',
    'accessory': 'Aksesuar fiyatı',
    'flyScreenPrice': 'Sineklik fiyatı',
  };

  String _missingSummary(Map<String, String> errors) {
    if (errors.isEmpty) return 'profil bilgisini tamamlayın.';
    final names = [for (final k in errors.keys) _fieldNames[k] ?? k];
    return '${names.join(', ')} alanlarını kontrol edin.';
  }

  @override
  Widget build(BuildContext context) {
    final built = _build();
    final e = built.errors;
    final u = widget.unit.symbol;
    Widget gap() => const SizedBox(height: 12);
    Widget title(String t) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(t, style: Theme.of(context).textTheme.titleSmall),
    );
    NumberField num(
      String key,
      TextEditingController c,
      String label, {
      String? suffix,
      bool integer = false,
    }) => NumberField(
      key: ValueKey('j_$key'),
      controller: c,
      label: label,
      suffix: suffix,
      integerOnly: integer,
      errorText: e[key],
    );

    void save() {
      setState(() => _submitted = true);
      final item = _build().item;
      if (item != null) Navigator.of(context).pop(item);
    }

    final dirty =
        _type != _i.type ||
        _flyScreen != _i.flyScreen ||
        _profileMode != _initialProfileMode ||
        _recipeId != _initialRecipeId ||
        [for (final (c, initial) in _initialTexts) c.text != initial]
            .any((changed) => changed);

    return EditorScaffold(
      title: _type.label,
      saveKey: 'j_save',
      onSave: save,
      isDirty: dirty,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Doğrama türü', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          JoineryTypePicker(
            value: _type,
            onChanged: (t) => setState(() => _type = t),
          ),
          gap(),
          TextField(
            key: const ValueKey('j_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Ad (isteğe bağlı, ör. Salon penceresi)',
            ),
          ),
          gap(),
          num('width', _width, 'En', suffix: u),
          gap(),
          num('height', _height, 'Boy', suffix: u),
          gap(),
          num('quantity', _quantity, 'Adet', suffix: 'adet', integer: true),
          title('Cam'),
          TextField(
            key: const ValueKey('j_glassType'),
            controller: _glassType,
            decoration: const InputDecoration(
              labelText: 'Cam türü (ör. Isıcam 4+16+4)',
            ),
          ),
          gap(),
          num('glassPrice', _glassPrice, 'Cam fiyatı (₺/m²)', suffix: '₺'),
          gap(),
          num(
            'glassArea',
            _glassArea,
            'Ölçülen cam alanı (adet başı)',
            suffix: 'm²',
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Boş bırakılırsa dış ölçü alanı kullanılır ve sonuç yaklaşık '
              'olarak işaretlenir.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          title('Profil'),
          DropdownButtonFormField<_ProfileMode>(
            isExpanded: true,
            key: const ValueKey('j_profileMode'),
            initialValue: _profileMode,
            dropdownColor: AppColors.card,
            decoration: const InputDecoration(labelText: 'Profil metrajı'),
            items: [
              for (final m in _ProfileMode.values)
                DropdownMenuItem(value: m, child: Text(m.label)),
            ],
            onChanged: (m) => setState(() => _profileMode = m!),
          ),
          if (_profileMode == _ProfileMode.manual) ...[
            gap(),
            num(
              'profileMeters',
              _profileMeters,
              'Profil metrajı (adet başı)',
              suffix: 'm',
            ),
            gap(),
            num(
              'profilePrice',
              _profilePrice,
              'Profil fiyatı (₺/m)',
              suffix: '₺',
            ),
          ],
          if (_profileMode == _ProfileMode.recipe) ...[
            gap(),
            if (_recipes.isEmpty)
              Text(
                'Henüz profil reçetesi yok. Doğrama ekranındaki "Profil '
                'reçeteleri" bölümünden oluşturabilirsiniz.',
                key: const ValueKey('j_noRecipes'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: const ValueKey('j_recipe'),
                initialValue: _recipeId,
                dropdownColor: AppColors.card,
                decoration: InputDecoration(
                  labelText: 'Reçete',
                  errorText: e['recipe'],
                ),
                items: [
                  for (final r in _recipes)
                    DropdownMenuItem(
                      value: r.id,
                      child: Text(
                        '${r.name}${r.verified ? '' : ' (doğrulanmamış)'}'
                        '${_isDeleted(r) ? ' (silinmiş)' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => setState(() => _recipeId = id),
              ),
          ],
          title('Aksesuar ve sineklik'),
          num(
            'accessory',
            _accessory,
            'Aksesuar ve mekanizma (₺/adet)',
            suffix: '₺',
          ),
          gap(),
          SwitchListTile(
            key: const ValueKey('j_flyScreen'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Sineklik'),
            value: _flyScreen,
            activeThumbColor: AppColors.gold,
            onChanged: (v) => setState(() => _flyScreen = v),
          ),
          if (_flyScreen)
            num(
              'flyScreenPrice',
              _flyScreenPrice,
              'Sineklik fiyatı (₺/adet)',
              suffix: '₺',
            ),
          if (_submitted && built.item == null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Kaydedilemedi: ${_missingSummary(e)}',
                key: const ValueKey('j_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('j_save'),
            onPressed: save,
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
