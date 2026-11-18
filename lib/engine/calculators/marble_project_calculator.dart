import 'package:decimal/decimal.dart';

import '../calculation_result.dart';
import '../calculator.dart';
import '../costing/cost_item.dart';
import '../costing/cost_sheet.dart';
import '../measurement.dart';
import '../money.dart';
import '../number_format.dart';
import '../price_steps.dart';
import '../pricing.dart';
import 'validation.dart';

/// Dikdörtgen tezgâh parçasının kenarları. Ön ve arka kenar uzunluğa,
/// sol ve sağ kenar derinliğe eşittir.
enum CountertopEdge {
  front('Ön'),
  back('Arka'),
  left('Sol'),
  right('Sağ');

  const CountertopEdge(this.label);

  final String label;
}

/// Kenar uzunluğu üzerinden (metre tül) fiyatlanan mermer işlemleri.
enum EdgeOperation {
  sakal('Sakal'),
  pah('Pah'),
  rodaj('Rodaj'),
  edgeFinish('Kenar işleme');

  const EdgeOperation(this.label);

  final String label;
}

/// Tezgâhın tek bir parçası (ör. "Ana tezgâh", "Ada", "Davlumbaz arası").
final class CountertopPiece {
  const CountertopPiece({
    required this.id,
    required this.name,
    this.length,
    this.depth,
    this.quantity = 1,
    this.edges = const {},
  });

  final String id;
  final String name;

  /// Seçili birimde uzunluk (ön/arka kenar).
  final Decimal? length;

  /// Seçili birimde derinlik (sol/sağ kenar).
  final Decimal? depth;
  final int quantity;

  /// Her işlem için seçili kenarlar.
  final Map<EdgeOperation, Set<CountertopEdge>> edges;

  Set<CountertopEdge> edgesFor(EdgeOperation op) => edges[op] ?? const {};

  CountertopPiece copyWith({
    String? name,
    Decimal? length,
    Decimal? depth,
    int? quantity,
    Map<EdgeOperation, Set<CountertopEdge>>? edges,
  }) => CountertopPiece(
    id: id,
    name: name ?? this.name,
    length: length ?? this.length,
    depth: depth ?? this.depth,
    quantity: quantity ?? this.quantity,
    edges: edges ?? this.edges,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'length': length?.toString(),
    'depth': depth?.toString(),
    'quantity': quantity,
    'edges': {
      for (final e in edges.entries)
        if (e.value.isNotEmpty) e.key.name: [for (final x in e.value) x.name],
    },
  };

  factory CountertopPiece.fromJson(Map<String, Object?> json) {
    Decimal? dec(Object? v) => v == null ? null : Decimal.parse(v as String);
    final edges = <EdgeOperation, Set<CountertopEdge>>{};
    final raw = (json['edges'] as Map?) ?? const {};
    for (final e in raw.entries) {
      edges[EdgeOperation.values.byName(e.key as String)] = {
        for (final x in e.value as List)
          CountertopEdge.values.byName(x as String),
      };
    }
    return CountertopPiece(
      id: json['id']! as String,
      name: (json['name'] as String?) ?? '',
      length: dec(json['length']),
      depth: dec(json['depth']),
      quantity: (json['quantity'] as int?) ?? 1,
      edges: edges,
    );
  }

  /// [op] işleminde [edge] kenarını açar/kapatır.
  CountertopPiece toggleEdge(EdgeOperation op, CountertopEdge edge) {
    final current = {...edgesFor(op)};
    if (!current.remove(edge)) current.add(edge);
    return copyWith(edges: {...edges, op: current});
  }
}

final class MarbleProjectInput {
  const MarbleProjectInput({
    required this.pieces,
    this.unit = LengthUnit.centimeter,
    this.materialWastePercent,
    this.materialPricePerSquareMeter,
    this.countertopLaborPerLinearMeter,
    this.edgePrices = const {},
    this.extras = const CostSheet(),
    this.vatPercent,
    this.discount,
  });

  final List<CountertopPiece> pieces;
  final LengthUnit unit;

  /// Yalnızca malzemeye (m²) uygulanır.
  final Decimal? materialWastePercent;

  /// Plaka/taş fiyatı, fireli m² üzerinden.
  final Money? materialPricePerSquareMeter;

  /// Tezgâh imalat işçiliği, tezgâh uzunluğu (mtül) üzerinden; fire
  /// uygulanmaz.
  final Money? countertopLaborPerLinearMeter;

  /// Kenar işlemlerinin mtül fiyatları.
  final Map<EdgeOperation, Money> edgePrices;

  /// Evye, ocak kesimi, delikler, nakliye, montaj ve diğer ek kalemler.
  final CostSheet extras;
  final Decimal? vatPercent;
  final Discount? discount;
}

/// Çok parçalı mermer/granit tezgâh hesabı.
///
/// Malzeme, işçilik ve fire birbirinden bağımsızdır:
/// * Malzeme = Σ(uzunluk × derinlik × adet) × (1 + malzeme firesi) × m² fiyatı
/// * Tezgâh işçiliği = Σ(uzunluk × adet) × mtül fiyatı (fire yok)
/// * Kenar işlemleri (sakal, pah, rodaj, kenar işleme) = seçilen kenarların
///   uzunlukları toplamı × mtül fiyatı (fire yok)
/// * Ek kalemler (evye, ocak kesimi, delikler, nakliye, montaj…) ortak
///   maliyet sistemiyle eklenir.
final class MarbleProjectCalculator
    implements Calculator<MarbleProjectInput, CalculationResult> {
  const MarbleProjectCalculator();

  @override
  String get id => 'marble.project';

  @override
  CalculationResult calculate(MarbleProjectInput input) {
    if (input.pieces.isEmpty) {
      throw const CalculationException('En az bir tezgâh parçası ekleyin.');
    }
    final waste = requirePercent(input.materialWastePercent, 'Malzeme firesi');
    final vatRate = requirePercent(input.vatPercent, 'KDV oranı');
    requireNonNegativePrice(
      input.materialPricePerSquareMeter,
      'Malzeme fiyatı',
    );
    requireNonNegativePrice(
      input.countertopLaborPerLinearMeter,
      'Tezgâh işçiliği',
    );
    for (final e in input.edgePrices.entries) {
      requireNonNegativePrice(e.value, '${e.key.label} fiyatı');
    }

    String m(Decimal v, [String u = 'm']) =>
        formatQuantity(v, u, maxDecimals: 6);
    final unit = input.unit;
    final steps = <String>[];

    var netArea = Decimal.zero;
    var runLength = Decimal.zero;
    final opLength = {for (final op in EdgeOperation.values) op: Decimal.zero};
    final opParts = {for (final op in EdgeOperation.values) op: <String>[]};

    for (final (index, piece) in input.pieces.indexed) {
      final label = piece.name.trim().isEmpty
          ? 'Parça ${index + 1}'
          : piece.name.trim();
      requireQuantity(piece.quantity);
      final l = requirePositiveLength(piece.length, unit, '$label uzunluğu');
      final dp = requirePositiveLength(piece.depth, unit, '$label derinliği');
      final q = Decimal.fromInt(piece.quantity);
      final qText = piece.quantity > 1 ? ' × ${piece.quantity} adet' : '';

      final area = (l * dp).times(q).squareMeters;
      netArea += area;
      runLength += l.meters * q;
      steps.add(
        '$label: ${formatDecimal(piece.length!)} × '
        '${formatDecimal(piece.depth!)} ${unit.symbol} = '
        '${m(l.meters)} × ${m(dp.meters)}$qText = ${m(area, 'm²')}',
      );

      for (final op in EdgeOperation.values) {
        for (final edge in CountertopEdge.values) {
          if (!piece.edgesFor(op).contains(edge)) continue;
          final edgeLength = switch (edge) {
            CountertopEdge.front || CountertopEdge.back => l.meters,
            CountertopEdge.left || CountertopEdge.right => dp.meters,
          };
          opLength[op] = opLength[op]! + edgeLength * q;
          opParts[op]!.add(
            '$label ${edge.label.toLowerCase()} (${m(edgeLength)}$qText)',
          );
        }
      }
    }

    if (input.pieces.length > 1) {
      steps.add('Toplam net alan = ${m(netArea, 'm²')}');
    }
    final wasteArea = netArea * percentFactor(waste);
    if (waste > Decimal.zero) {
      steps.add(
        'Malzeme firesi ${formatPercent(waste)}: ${m(netArea, 'm²')} × '
        '${formatDecimal(percentFactor(waste))} = ${m(wasteArea, 'm²')} '
        '(fire yalnızca malzemeye uygulanır)',
      );
    }
    steps.add('Tezgâh uzunluğu = Σ(uzunluk × adet) = ${m(runLength, 'mtül')}');
    for (final op in EdgeOperation.values) {
      if (opParts[op]!.isEmpty) continue;
      steps.add(
        '${op.label} = ${opParts[op]!.join(' + ')} = '
        '${m(opLength[op]!, 'mtül')}',
      );
    }

    final figures = [
      ResultFigure(label: 'Net alan', value: netArea, unit: 'm²'),
      if (waste > Decimal.zero)
        ResultFigure(
          label: 'Fireli alan (${formatPercent(waste)})',
          value: wasteArea,
          unit: 'm²',
          highlighted: true,
        ),
      ResultFigure(
        label: 'Tezgâh uzunluğu',
        value: runLength,
        unit: 'mtül',
        highlighted: waste == Decimal.zero,
      ),
      for (final op in EdgeOperation.values)
        if (opLength[op]! > Decimal.zero)
          ResultFigure(label: op.label, value: opLength[op]!, unit: 'mtül'),
    ];

    final warnings = <String>[
      for (final op in EdgeOperation.values)
        if (opLength[op]! > Decimal.zero && input.edgePrices[op] == null)
          '${op.label} kenarları seçildi ancak mtül fiyatı girilmedi; '
              'tutara eklenmedi.',
    ];

    final lines = <CostLine>[
      if (input.materialPricePerSquareMeter case final price?)
        CostLine(
          label: 'Malzeme',
          kind: CostKind.material,
          quantity: wasteArea,
          unit: 'm²',
          unitPrice: price,
        ),
      if (input.countertopLaborPerLinearMeter case final price?)
        CostLine(
          label: 'Tezgâh işçiliği',
          kind: CostKind.labor,
          quantity: runLength,
          unit: 'mtül',
          unitPrice: price,
        ),
      for (final op in EdgeOperation.values)
        if (input.edgePrices[op] case final price?
            when opLength[op]! > Decimal.zero)
          CostLine(
            label: op.label,
            kind: CostKind.labor,
            quantity: opLength[op]!,
            unit: 'mtül',
            unitPrice: price,
          ),
    ];

    final price = buildPriceSummary(
      lines: lines,
      steps: steps,
      extras: input.extras,
      vatPercent: vatRate,
      discount: input.discount,
    );

    return CalculationResult(
      figures: figures,
      price: price,
      steps: steps,
      warnings: warnings,
    );
  }
}

/// Mermer ve granit için hazır ek kalem şablonları.
abstract final class MarbleCatalog {
  static const List<CostTemplate> extras = [
    CostTemplate(
      name: 'Evye bedeli',
      category: CostKind.accessory,
      unit: CostUnit.piece,
    ),
    CostTemplate(
      name: 'Evye montajı',
      category: CostKind.labor,
      unit: CostUnit.piece,
    ),
    CostTemplate(
      name: 'Evye kesim ve işleme',
      category: CostKind.labor,
      unit: CostUnit.piece,
    ),
    CostTemplate(
      name: 'Ocak kesimi',
      category: CostKind.labor,
      unit: CostUnit.piece,
    ),
    CostTemplate(
      name: 'Batarya deliği',
      category: CostKind.labor,
      unit: CostUnit.piece,
    ),
    CostTemplate(
      name: 'Diğer delik işlemleri',
      category: CostKind.labor,
      unit: CostUnit.piece,
    ),
    CostTemplate(
      name: 'Nakliye',
      category: CostKind.shipping,
      unit: CostUnit.service,
    ),
    CostTemplate(
      name: 'Montaj',
      category: CostKind.labor,
      unit: CostUnit.linearMeter,
    ),
  ];
}
