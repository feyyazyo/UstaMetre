import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../engine/calculators/marble_project_calculator.dart';
import '../../../engine/measurement.dart';
import '../../../shared/input_parsing.dart';
import '../widgets/number_field.dart';

/// Tezgâh parçası ekleme/düzenleme. Kaydedilirse parçayı döner.
Future<CountertopPiece?> showPieceEditor(
  BuildContext context, {
  required CountertopPiece initial,
  required LengthUnit unit,
}) => Navigator.of(context).push<CountertopPiece>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PieceEditorPage(initial: initial, unit: unit),
  ),
);

class PieceEditorPage extends StatefulWidget {
  const PieceEditorPage({super.key, required this.initial, required this.unit});

  final CountertopPiece initial;
  final LengthUnit unit;

  @override
  State<PieceEditorPage> createState() => _PieceEditorPageState();
}

class _PieceEditorPageState extends State<PieceEditorPage> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _length = TextEditingController(
    text: decimalToInput(widget.initial.length),
  );
  late final _depth = TextEditingController(
    text: decimalToInput(widget.initial.depth),
  );
  late final _quantity = TextEditingController(
    text: '${widget.initial.quantity}',
  );
  late CountertopPiece _piece = widget.initial;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_length, _depth, _quantity]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _length, _depth, _quantity]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final length = parseField(_length.text);
    final depth = parseField(_depth.text);
    final quantity = parseCountField(_quantity.text);
    String? need(ParsedField<Object> f) =>
        f.error ?? (_submitted && f.value == null ? 'Bu alan gerekli' : null);
    final u = widget.unit.symbol;

    return Scaffold(
      appBar: AppBar(title: const Text('Tezgâh parçası')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const ValueKey('piece_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Parça adı (ör. Ana tezgâh, Ada)',
            ),
          ),
          const SizedBox(height: 12),
          NumberField(
            key: const ValueKey('piece_length'),
            controller: _length,
            label: 'Uzunluk (ön/arka kenar)',
            suffix: u,
            errorText: need(length),
          ),
          const SizedBox(height: 12),
          NumberField(
            key: const ValueKey('piece_depth'),
            controller: _depth,
            label: 'Derinlik (sol/sağ kenar)',
            suffix: u,
            errorText: need(depth),
          ),
          const SizedBox(height: 12),
          NumberField(
            key: const ValueKey('piece_quantity'),
            controller: _quantity,
            label: 'Adet',
            suffix: 'adet',
            integerOnly: true,
            errorText: quantity.error,
          ),
          const SizedBox(height: 24),
          Text(
            'Kenar işlemleri',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Her işlem için işlenecek kenarları seçin. Metre tül, seçilen '
            'kenarların uzunlukları toplanarak hesaplanır.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          for (final op in EdgeOperation.values) ...[
            const SizedBox(height: 12),
            Text(op.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final edge in CountertopEdge.values)
                  FilterChip(
                    key: ValueKey('edge_${op.name}_${edge.name}'),
                    label: Text(edge.label),
                    selected: _piece.edgesFor(op).contains(edge),
                    selectedColor: AppColors.gold,
                    checkmarkColor: AppColors.onGold,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    labelStyle: TextStyle(
                      color: _piece.edgesFor(op).contains(edge)
                          ? AppColors.onGold
                          : AppColors.textPrimary,
                    ),
                    onSelected: (_) =>
                        setState(() => _piece = _piece.toggleEdge(op, edge)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('piece_save'),
            onPressed: () {
              setState(() => _submitted = true);
              if (length.value == null ||
                  depth.value == null ||
                  quantity.value == null) {
                return;
              }
              Navigator.of(context).pop(
                _piece.copyWith(
                  name: _name.text.trim(),
                  length: length.value,
                  depth: depth.value,
                  quantity: quantity.value,
                ),
              );
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
