import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/catalog_scope.dart';
import '../../../engine/calculators/pvc_joinery_calculator.dart';
import '../../../engine/money.dart';
import '../../../shared/input_parsing.dart';
import '../widgets/number_field.dart';

/// Kullanıcının profil reçeteleri.
class RecipeListPage extends StatelessWidget {
  const RecipeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = CatalogScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil reçeteleri')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Reçetede kasa, kanat, orta kayıt ve diğer profil bileşenlerini '
            'ayrı ayrı tanımlayın. Kesim payları açılım türüne ve üretici '
            'sistemine göre değişir; formülleri kendi sisteminize göre '
            'kontrol etmeden "doğrulandı" olarak işaretlemeyin.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final r in catalog.recipes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                key: ValueKey('recipe_${r.id}'),
                child: ListTile(
                  title: Text(r.name),
                  subtitle: Text(
                    '${r.components.map((c) => c.name).join(', ')}\n'
                    '${r.verified ? 'Doğrulandı' : 'Doğrulanmamış (tahmini)'}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RecipeEditorPage(initial: r),
                    ),
                  ),
                ),
              ),
            ),
          OutlinedButton.icon(
            key: const ValueKey('add_recipe'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecipeEditorPage(initial: catalog.newRecipe()),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Reçete oluştur'),
          ),
        ],
      ),
    );
  }
}

class _ComponentControllers {
  _ComponentControllers(ProfileComponent c)
    : name = TextEditingController(text: c.name),
      role = c.role,
      widthFactor = TextEditingController(text: decimalToInput(c.widthFactor)),
      heightFactor = TextEditingController(
        text: decimalToInput(c.heightFactor),
      ),
      offset = TextEditingController(
        text: c.offsetMeters == Decimal.zero
            ? ''
            : decimalToInput(c.offsetMeters),
      ),
      price = TextEditingController(
        text: c.pricePerMeter == Money.zero
            ? ''
            : moneyToInput(c.pricePerMeter),
      );

  final TextEditingController name;
  ProfileRole role;
  final TextEditingController widthFactor;
  final TextEditingController heightFactor;
  final TextEditingController offset;
  final TextEditingController price;

  List<TextEditingController> get all => [
    name,
    widthFactor,
    heightFactor,
    offset,
    price,
  ];

  void dispose() {
    for (final c in all) {
      c.dispose();
    }
  }
}

/// Reçete düzenleme: ad, doğrulama durumu, bileşenler ve formülleri.
class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({super.key, required this.initial});

  final ProfileRecipe initial;

  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _note = TextEditingController(text: widget.initial.note);
  late bool _verified = widget.initial.verified;
  late final List<_ComponentControllers> _components = [
    for (final c in widget.initial.components) _watch(_ComponentControllers(c)),
  ];
  String? _error;

  _ComponentControllers _watch(_ComponentControllers c) {
    for (final t in c.all) {
      t.addListener(() => setState(() => _error = null));
    }
    return c;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    for (final c in _components) {
      c.dispose();
    }
    super.dispose();
  }

  ProfileRecipe? _build() {
    if (_name.text.trim().isEmpty) {
      _error = 'Reçete adı girin.';
      return null;
    }
    if (_components.isEmpty) {
      _error = 'En az bir profil bileşeni ekleyin.';
      return null;
    }
    final components = <ProfileComponent>[];
    for (final (i, c) in _components.indexed) {
      final label = c.name.text.trim().isEmpty
          ? 'Bileşen ${i + 1}'
          : c.name.text.trim();
      final wf = parseField(c.widthFactor.text);
      final hf = parseField(c.heightFactor.text);
      final off = parseField(c.offset.text, allowNegative: true);
      final price = parseMoneyField(c.price.text);
      final error = wf.error ?? hf.error ?? off.error ?? price.error;
      if (error != null) {
        _error = '$label: $error';
        return null;
      }
      if (c.name.text.trim().isEmpty) {
        _error = '${i + 1}. bileşenin adını girin.';
        return null;
      }
      if (price.value == null) {
        _error = '$label: metre fiyatı girin.';
        return null;
      }
      components.add(
        ProfileComponent(
          name: c.name.text.trim(),
          role: c.role,
          widthFactor: wf.value ?? Decimal.zero,
          heightFactor: hf.value ?? Decimal.zero,
          offsetMeters: off.value,
          pricePerMeter: price.value!,
        ),
      );
    }
    return widget.initial.copyWith(
      name: _name.text.trim(),
      note: _note.text.trim(),
      verified: _verified,
      components: components,
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = CatalogScope.of(context);
    final isNew = !catalog.recipes.any((r) => r.id == widget.initial.id);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil reçetesi'),
        actions: [
          if (!isNew)
            IconButton(
              key: const ValueKey('delete_recipe'),
              tooltip: 'Reçeteyi sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final nav = Navigator.of(context);
                await catalog.deleteRecipe(widget.initial.id);
                nav.pop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const ValueKey('recipe_name'),
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Reçete adı (ör. 70 mm sistem, tek açılım)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('recipe_note'),
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Not (üretici sistemi, açılım türü…)',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const ValueKey('recipe_verified'),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.gold,
            title: const Text('Formüller doğrulandı'),
            subtitle: const Text(
              'Yalnızca kesim formüllerini kendi üretici sisteminize göre '
              'kontrol ettiyseniz işaretleyin. İşaretli değilse sonuçlar '
              '"tahmini" olarak gösterilir.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            value: _verified,
            onChanged: (v) => setState(() => _verified = v),
          ),
          const SizedBox(height: 8),
          const Text(
            'Uzunluk formülü (adet başı, metre): '
            'En katsayısı × En + Boy katsayısı × Boy + Sabit pay',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          for (final (i, c) in _components.indexed)
            Card(
              key: ValueKey('component_$i'),
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: ValueKey('component_${i}_name'),
                            controller: c.name,
                            decoration: const InputDecoration(
                              labelText: 'Bileşen adı',
                            ),
                          ),
                        ),
                        IconButton(
                          key: ValueKey('component_${i}_delete'),
                          tooltip: 'Bileşeni sil',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _components.removeAt(i).dispose();
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ProfileRole>(
                      isExpanded: true,
                      initialValue: c.role,
                      dropdownColor: AppColors.card,
                      decoration: const InputDecoration(labelText: 'Tür'),
                      items: [
                        for (final r in ProfileRole.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: (r) => setState(() => c.role = r!),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: NumberField(
                            key: ValueKey('component_${i}_wf'),
                            controller: c.widthFactor,
                            label: 'En katsayısı',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: NumberField(
                            key: ValueKey('component_${i}_hf'),
                            controller: c.heightFactor,
                            label: 'Boy katsayısı',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: NumberField(
                            key: ValueKey('component_${i}_offset'),
                            controller: c.offset,
                            label: 'Sabit pay',
                            suffix: 'm',
                            allowNegative: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: NumberField(
                            key: ValueKey('component_${i}_price'),
                            controller: c.price,
                            label: 'Fiyat (₺/m)',
                            suffix: '₺',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('add_component'),
            onPressed: () => setState(
              () => _components.add(
                _watch(
                  _ComponentControllers(
                    ProfileComponent(
                      name: '',
                      role: ProfileRole.sash,
                      widthFactor: Decimal.zero,
                      heightFactor: Decimal.zero,
                      pricePerMeter: Money.zero,
                    ),
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Bileşen ekle'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                key: const ValueKey('recipe_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('recipe_save'),
            onPressed: () async {
              final recipe = _build();
              if (recipe == null) {
                setState(() {});
                return;
              }
              final nav = Navigator.of(context);
              await catalog.saveRecipe(recipe);
              nav.pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
