import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/catalog_scope.dart';
import '../../../engine/calculation_result.dart';
import '../../../engine/calculator.dart';
import '../../../engine/calculators/marble_project_calculator.dart';
import '../../../engine/costing/cost_sheet.dart';
import '../../../engine/measurement.dart';
import '../../../engine/money.dart';
import '../../../engine/number_format.dart';
import '../../../shared/input_parsing.dart';
import '../../costing/cost_items_section.dart';
import '../../costing/pricing_options.dart';
import '../widgets/number_field.dart';
import '../widgets/project_scaffold.dart';
import '../widgets/result_card.dart';
import 'piece_editor_page.dart';

/// Mermer ve granit tezgâh projesi: çok parçalı tezgâh, kenar işlemleri,
/// bağımsız malzeme / fire / işçilik, ek kalemler, indirim ve KDV.
class MarbleProjectPage extends StatefulWidget {
  const MarbleProjectPage({super.key});

  @override
  State<MarbleProjectPage> createState() => _MarbleProjectPageState();
}

class _MarbleProjectPageState extends State<MarbleProjectPage> {
  LengthUnit _unit = LengthUnit.centimeter;
  List<CountertopPiece> _pieces = const [];
  CostSheet _extras = const CostSheet();
  final _pricing = PricingOptionsController();
  final _waste = TextEditingController();
  final _materialPrice = TextEditingController();
  final _labor = TextEditingController();
  final _edgePrices = {
    for (final op in EdgeOperation.values) op: TextEditingController(),
  };

  List<TextEditingController> get _fields => [
    _waste,
    _materialPrice,
    _labor,
    ..._edgePrices.values,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _fields) {
      c.addListener(_changed);
    }
    _pricing.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    _pricing.dispose();
    super.dispose();
  }

  Future<void> _addPiece() async {
    final catalog = CatalogScope.of(context);
    final piece = await showPieceEditor(
      context,
      unit: _unit,
      initial: CountertopPiece(
        id: catalog.ids.next(),
        name: 'Parça ${_pieces.length + 1}',
      ),
    );
    if (piece != null) setState(() => _pieces = [..._pieces, piece]);
  }

  Future<void> _editPiece(CountertopPiece piece) async {
    final edited = await showPieceEditor(context, unit: _unit, initial: piece);
    if (edited == null) return;
    setState(
      () => _pieces = [for (final p in _pieces) p.id == edited.id ? edited : p],
    );
  }

  void _copyPiece(CountertopPiece piece) {
    final copy = CountertopPiece(
      id: CatalogScope.of(context).ids.next(),
      name: '${piece.name} (kopya)',
      length: piece.length,
      depth: piece.depth,
      quantity: piece.quantity,
      edges: piece.edges,
    );
    final i = _pieces.indexWhere((p) => p.id == piece.id);
    setState(() => _pieces = [..._pieces]..insert(i + 1, copy));
  }

  ({CalculationResult? result, String? message, Map<String, String> errors})
  _evaluate() {
    final errors = <String, String>{};
    Money? money(String key, TextEditingController c) {
      final p = parseMoneyField(c.text);
      if (p.error != null) errors[key] = p.error!;
      return p.value;
    }

    final waste = parseField(_waste.text);
    if (waste.error != null) errors['waste'] = waste.error!;
    final materialPrice = money('materialPrice', _materialPrice);
    final labor = money('labor', _labor);
    final edgePrices = <EdgeOperation, Money>{};
    for (final e in _edgePrices.entries) {
      final v = money('edge_${e.key.name}', e.value);
      if (v != null) edgePrices[e.key] = v;
    }
    final pricingError = _pricing.error;
    if (errors.isNotEmpty || pricingError != null) {
      return (
        result: null,
        message: pricingError != null
            ? 'Fiyatlandırma: $pricingError'
            : 'Hatalı alanları düzeltin.',
        errors: errors,
      );
    }
    try {
      final result = const MarbleProjectCalculator().calculate(
        MarbleProjectInput(
          pieces: _pieces,
          unit: _unit,
          materialWastePercent: waste.value,
          materialPricePerSquareMeter: materialPrice,
          countertopLaborPerLinearMeter: labor,
          edgePrices: edgePrices,
          extras: _extras,
          vatPercent: _pricing.vatPercent.value,
          discount: _pricing.discount.value,
        ),
      );
      return (result: result, message: null, errors: errors);
    } on CalculationException catch (e) {
      return (result: null, message: e.message, errors: errors);
    }
  }

  String _pieceSummary(CountertopPiece p) {
    final dims =
        '${p.length == null ? '?' : formatDecimal(p.length!)} × '
        '${p.depth == null ? '?' : formatDecimal(p.depth!)} ${_unit.symbol}'
        '${p.quantity > 1 ? ' × ${p.quantity} adet' : ''}';
    final ops = [
      for (final op in EdgeOperation.values)
        if (p.edgesFor(op).isNotEmpty)
          '${op.label}: ${[for (final e in CountertopEdge.values)
            if (p.edgesFor(op).contains(e)) e.label].join(', ')}',
    ];
    return ops.isEmpty ? dims : '$dims\n${ops.join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final eval = _evaluate();
    final result = eval.result;

    Widget priceField(String key, TextEditingController c, String label) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NumberField(
            key: ValueKey('field_$key'),
            controller: c,
            label: label,
            suffix: '₺',
            errorText: eval.errors[key],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Mermer tezgâh projesi')),
      bottomNavigationBar: LiveTotalBar(result: result, message: eval.message),
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
              'Tezgâh parçaları',
              subtitle:
                  'Tezgâh birden fazla parçadan oluşabilir (L tezgâh, ada, '
                  'davlumbaz arası…). Her parçanın ölçüsü ve adedi ayrıdır.',
            ),
            for (final p in _pieces)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  key: ValueKey('piece_${p.id}'),
                  child: ListTile(
                    contentPadding: const EdgeInsets.only(left: 16, right: 4),
                    title: Text(p.name),
                    subtitle: Text(
                      _pieceSummary(p),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    onTap: () => _editPiece(p),
                    trailing: ItemActionsMenu(
                      key: ValueKey('piece_menu_${p.id}'),
                      onEdit: () => _editPiece(p),
                      onCopy: () => _copyPiece(p),
                      onDelete: () => setState(
                        () => _pieces = [
                          for (final x in _pieces)
                            if (x.id != p.id) x,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            OutlinedButton.icon(
              key: const ValueKey('add_piece'),
              onPressed: _addPiece,
              icon: const Icon(Icons.add),
              label: const Text('Parça ekle'),
            ),
            const SectionTitle(
              'Malzeme',
              subtitle: 'Fire yalnızca malzemeye (m²) uygulanır.',
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NumberField(
                key: const ValueKey('field_waste'),
                controller: _waste,
                label: 'Malzeme firesi',
                suffix: '%',
                errorText: eval.errors['waste'],
              ),
            ),
            priceField(
              'materialPrice',
              _materialPrice,
              'Malzeme fiyatı (₺/m²)',
            ),
            const SectionTitle(
              'İşçilik',
              subtitle:
                  'İşçilik net ölçüden hesaplanır; fire uygulanmaz. Kenar '
                  'işlemleri, parçalarda seçilen kenarların toplam '
                  'uzunluğundan (mtül) fiyatlanır.',
            ),
            priceField(
              'labor',
              _labor,
              'Tezgâh işçiliği (₺/mtül, tezgâh uzunluğu)',
            ),
            for (final op in EdgeOperation.values)
              priceField(
                'edge_${op.name}',
                _edgePrices[op]!,
                '${op.label} (₺/mtül)',
              ),
            const SectionTitle(
              'Ek kalemler',
              subtitle:
                  'Evye, ocak kesimi, batarya deliği, diğer delikler, '
                  'nakliye, montaj…',
            ),
            CostItemsSection(
              sheet: _extras,
              templates: MarbleCatalog.extras,
              onChanged: (s) => setState(() => _extras = s),
            ),
            const SectionTitle('Fiyatlandırma'),
            PricingOptionsSection(controller: _pricing),
            const SizedBox(height: 20),
            if (result != null)
              ResultCard(result: result, display: _pricing.display)
            else
              ResultPlaceholder(message: eval.message ?? ''),
          ],
        ),
      ),
    );
  }
}
