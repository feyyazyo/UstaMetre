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

enum JoineryType {
  window('Pencere'),
  door('Kapı'),
  balconyDoor('Balkon kapısı');

  const JoineryType(this.label);

  final String label;
}

enum ProfileRole {
  frame('Kasa'),
  sash('Kanat'),
  mullion('Orta kayıt'),
  glazingBead('Çıta'),
  other('Diğer');

  const ProfileRole(this.label);

  final String label;
}

/// Reçetedeki bir profil bileşeni. Metraj formülü (metre, tek doğrama için):
///
/// `genişlik katsayısı × En + yükseklik katsayısı × Boy + sabit pay`
///
/// Örn. kasa çevresi: 2 × En + 2 × Boy + 0. Kanat ve çıta paylarını açılım
/// türü ve üretici sistemi belirler; bu katsayıları kullanıcı girer.
final class ProfileComponent {
  const ProfileComponent({
    required this.name,
    required this.role,
    required this.widthFactor,
    required this.heightFactor,
    required this.pricePerMeter,
    Decimal? offsetMeters,
  }) : _offset = offsetMeters;

  final String name;
  final ProfileRole role;
  final Decimal widthFactor;
  final Decimal heightFactor;
  final Decimal? _offset;
  final Money pricePerMeter;

  /// Metre cinsinden sabit pay (negatif olabilir, ör. kesim payı düşümü).
  Decimal get offsetMeters => _offset ?? Decimal.zero;

  /// Tek doğrama için bileşen uzunluğu (m).
  Decimal metersFor(Length width, Length height) =>
      widthFactor * width.meters + heightFactor * height.meters + offsetMeters;

  String get formula {
    final parts = <String>[
      if (widthFactor != Decimal.zero) '${formatDecimal(widthFactor)} × En',
      if (heightFactor != Decimal.zero) '${formatDecimal(heightFactor)} × Boy',
      if (offsetMeters != Decimal.zero)
        '${offsetMeters < Decimal.zero ? '−' : ''}'
            '${formatDecimal(offsetMeters.abs())} m',
    ];
    return parts.isEmpty ? '0' : parts.join(' + ').replaceAll('+ −', '− ');
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'role': role.name,
    'widthFactor': widthFactor.toString(),
    'heightFactor': heightFactor.toString(),
    'offsetMeters': offsetMeters.toString(),
    'pricePerMeterKurus': pricePerMeter.kurus.toString(),
  };

  factory ProfileComponent.fromJson(Map<String, Object?> json) =>
      ProfileComponent(
        name: json['name']! as String,
        role: ProfileRole.values.byName(json['role']! as String),
        widthFactor: Decimal.parse(json['widthFactor']! as String),
        heightFactor: Decimal.parse(json['heightFactor']! as String),
        offsetMeters: Decimal.parse(json['offsetMeters']! as String),
        pricePerMeter: Money.fromKurusBig(
          BigInt.parse(json['pricePerMeterKurus']! as String),
        ),
      );
}

/// Kullanıcının oluşturduğu profil reçetesi (kasa, kanat, orta kayıt…).
///
/// [verified] `false` ise sonuç **tahmini** olarak işaretlenir ve uyarı
/// gösterilir. Kesim formülleri açılım türüne ve üretici sistemine göre
/// değiştiği için reçeteler varsayılan olarak doğrulanmamıştır.
final class ProfileRecipe {
  const ProfileRecipe({
    required this.id,
    required this.name,
    required this.components,
    this.verified = false,
    this.note = '',
  });

  final String id;
  final String name;
  final List<ProfileComponent> components;
  final bool verified;
  final String note;

  ProfileRecipe copyWith({
    String? name,
    List<ProfileComponent>? components,
    bool? verified,
    String? note,
  }) => ProfileRecipe(
    id: id,
    name: name ?? this.name,
    components: components ?? this.components,
    verified: verified ?? this.verified,
    note: note ?? this.note,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'verified': verified,
    'note': note,
    'components': [for (final c in components) c.toJson()],
  };

  factory ProfileRecipe.fromJson(Map<String, Object?> json) => ProfileRecipe(
    id: json['id']! as String,
    name: json['name']! as String,
    verified: (json['verified'] as bool?) ?? false,
    note: (json['note'] as String?) ?? '',
    components: [
      for (final c in json['components']! as List)
        ProfileComponent.fromJson((c! as Map).cast<String, Object?>()),
    ],
  );
}

/// Doğramanın profil metrajı nasıl bulunacak.
sealed class ProfileSpec {
  const ProfileSpec();
}

/// Kullanıcı tek doğrama için toplam profil metrajını kendisi girer.
final class ManualProfile extends ProfileSpec {
  const ManualProfile({
    required this.metersPerUnit,
    required this.pricePerMeter,
  });

  final Decimal metersPerUnit;
  final Money pricePerMeter;
}

/// Profil metrajı reçeteden hesaplanır.
final class RecipeProfile extends ProfileSpec {
  const RecipeProfile(this.recipe);

  final ProfileRecipe recipe;
}

/// Tek bir doğrama kalemi (ör. "Salon penceresi, 3 adet").
final class JoineryItem {
  const JoineryItem({
    required this.id,
    required this.type,
    this.name = '',
    this.width,
    this.height,
    this.quantity = 1,
    this.glassType = '',
    this.glassPricePerSquareMeter,
    this.glassAreaPerUnit,
    this.profile,
    this.accessoryPricePerUnit,
    this.flyScreen = false,
    this.flyScreenPricePerUnit,
  });

  final String id;
  final JoineryType type;
  final String name;

  /// Seçili birimde en ve boy (dış ölçü).
  final Decimal? width;
  final Decimal? height;
  final int quantity;

  /// Cam türü (ör. "Isıcam 4+16+4 Low-E").
  final String glassType;
  final Money? glassPricePerSquareMeter;

  /// Tek doğrama için ölçülmüş cam alanı (m²). Verilmezse dış ölçü alanı
  /// kullanılır ve sonuç yaklaşık olarak işaretlenir.
  final Decimal? glassAreaPerUnit;

  final ProfileSpec? profile;

  /// Aksesuar ve mekanizma (kol, menteşe, çok noktalı kilit…) — adet başı.
  final Money? accessoryPricePerUnit;
  final bool flyScreen;
  final Money? flyScreenPricePerUnit;

  String labelAt(int index) =>
      name.trim().isEmpty ? '${type.label} ${index + 1}' : name.trim();

  JoineryItem copyWith({
    JoineryType? type,
    String? name,
    Decimal? width,
    Decimal? height,
    int? quantity,
    String? glassType,
    Money? glassPricePerSquareMeter,
    Decimal? glassAreaPerUnit,
    ProfileSpec? profile,
    Money? accessoryPricePerUnit,
    bool? flyScreen,
    Money? flyScreenPricePerUnit,
    bool clearGlassArea = false,
    bool clearProfile = false,
  }) => JoineryItem(
    id: id,
    type: type ?? this.type,
    name: name ?? this.name,
    width: width ?? this.width,
    height: height ?? this.height,
    quantity: quantity ?? this.quantity,
    glassType: glassType ?? this.glassType,
    glassPricePerSquareMeter:
        glassPricePerSquareMeter ?? this.glassPricePerSquareMeter,
    glassAreaPerUnit: clearGlassArea
        ? null
        : (glassAreaPerUnit ?? this.glassAreaPerUnit),
    profile: clearProfile ? null : (profile ?? this.profile),
    accessoryPricePerUnit: accessoryPricePerUnit ?? this.accessoryPricePerUnit,
    flyScreen: flyScreen ?? this.flyScreen,
    flyScreenPricePerUnit: flyScreenPricePerUnit ?? this.flyScreenPricePerUnit,
  );
}

final class PvcProjectInput {
  const PvcProjectInput({
    required this.items,
    this.unit = LengthUnit.centimeter,
    this.profileWastePercent,
    this.glassWastePercent,
    this.extras = const CostSheet(),
    this.vatPercent,
    this.discount,
  });

  final List<JoineryItem> items;
  final LengthUnit unit;

  /// Profil kesim firesi; yalnızca profil metrajına uygulanır.
  final Decimal? profileWastePercent;

  /// Cam firesi; yalnızca cam alanına uygulanır.
  final Decimal? glassWastePercent;

  /// Montaj, nakliye ve diğer ek kalemler.
  final CostSheet extras;
  final Decimal? vatPercent;
  final Discount? discount;
}

/// PVC kapı ve pencere doğrama hesabı.
///
/// Kesin hesaplar: dış ölçü alanı, girilen/ölçülen değerlerle yapılan
/// fiyatlar. Tahmini hesaplar (uyarıyla işaretlenir): cam alanının dış
/// ölçüden alınması ve doğrulanmamış profil reçeteleri.
final class PvcJoineryCalculator
    implements Calculator<PvcProjectInput, CalculationResult> {
  const PvcJoineryCalculator();

  @override
  String get id => 'pvc.joinery';

  @override
  CalculationResult calculate(PvcProjectInput input) {
    if (input.items.isEmpty) {
      throw const CalculationException('En az bir doğrama kalemi ekleyin.');
    }
    final profileWaste = requirePercent(
      input.profileWastePercent,
      'Profil firesi',
    );
    final glassWaste = requirePercent(input.glassWastePercent, 'Cam firesi');
    final vatRate = requirePercent(input.vatPercent, 'KDV oranı');

    String m(Decimal v, [String u = 'm']) =>
        formatQuantity(v, u, maxDecimals: 6);
    final steps = <String>[];
    final warnings = <String>[];
    final lines = <CostLine>[];
    var totalArea = Decimal.zero;
    var totalGlass = Decimal.zero;
    var totalProfile = Decimal.zero;
    final profileFactor = percentFactor(profileWaste);
    final glassFactor = percentFactor(glassWaste);

    for (final (index, item) in input.items.indexed) {
      final label = item.labelAt(index);
      requireQuantity(item.quantity);
      final w = requirePositiveLength(item.width, input.unit, '$label eni');
      final h = requirePositiveLength(item.height, input.unit, '$label boyu');
      final q = Decimal.fromInt(item.quantity);
      final qText = item.quantity > 1 ? ' × ${item.quantity} adet' : '';

      final area = (w * h).times(q).squareMeters;
      totalArea += area;
      steps.add(
        '$label (${item.type.label}): ${m(w.meters)} × ${m(h.meters)}$qText '
        '= ${m(area, 'm²')}',
      );

      // Cam
      final glassPrice = item.glassPricePerSquareMeter;
      requireNonNegativePrice(glassPrice, '$label cam fiyatı');
      if (glassPrice != null) {
        final measured = item.glassAreaPerUnit;
        if (measured != null && measured <= Decimal.zero) {
          throw CalculationException(
            '$label cam alanı sıfırdan büyük olmalıdır.',
          );
        }
        final perUnit = measured ?? (w * h).squareMeters;
        final glass = perUnit * q * glassFactor;
        totalGlass += glass;
        final source = measured == null
            ? 'dış ölçüden (yaklaşık)'
            : 'ölçülen cam alanı';
        steps.add(
          '$label cam: ${m(perUnit, 'm²')} ($source)$qText'
          '${glassWaste > Decimal.zero ? ' × ${formatDecimal(glassFactor)} fire' : ''}'
          ' = ${m(glass, 'm²')}',
        );
        if (measured == null) {
          warnings.add(
            '$label: cam alanı dış ölçüden alındı; kasa ve kanat payı '
            'düşülmedi. Kesin fiyat için cam ölçüsünü girin.',
          );
        }
        final type = item.glassType.trim();
        lines.add(
          CostLine(
            label: '$label – Cam${type.isEmpty ? '' : ' ($type)'}',
            kind: CostKind.material,
            quantity: glass,
            unit: 'm²',
            unitPrice: glassPrice,
          ),
        );
      }

      // Profil
      switch (item.profile) {
        case null:
          break;
        case ManualProfile(:final metersPerUnit, :final pricePerMeter):
          if (metersPerUnit <= Decimal.zero) {
            throw CalculationException(
              '$label profil metrajı sıfırdan büyük olmalıdır.',
            );
          }
          requireNonNegativePrice(pricePerMeter, '$label profil fiyatı');
          final meters = metersPerUnit * q * profileFactor;
          totalProfile += meters;
          steps.add(
            '$label profil (manuel): ${m(metersPerUnit)}$qText'
            '${profileWaste > Decimal.zero ? ' × ${formatDecimal(profileFactor)} fire' : ''}'
            ' = ${m(meters)}',
          );
          lines.add(
            CostLine(
              label: '$label – Profil',
              kind: CostKind.material,
              quantity: meters,
              unit: 'm',
              unitPrice: pricePerMeter,
            ),
          );
        case RecipeProfile(:final recipe):
          if (recipe.components.isEmpty) {
            throw CalculationException(
              '"${recipe.name}" reçetesinde profil bileşeni yok.',
            );
          }
          final tag = recipe.verified ? '' : ' (tahmini)';
          for (final c in recipe.components) {
            requireNonNegativePrice(c.pricePerMeter, '${c.name} fiyatı');
            final perUnit = c.metersFor(w, h);
            if (perUnit <= Decimal.zero) {
              throw CalculationException(
                '$label: "${c.name}" için hesaplanan uzunluk sıfır veya '
                'negatif. Reçete formülünü kontrol edin.',
              );
            }
            final meters = perUnit * q * profileFactor;
            totalProfile += meters;
            steps.add(
              '$label ${c.name}$tag: ${c.formula} = ${m(perUnit)}$qText'
              '${profileWaste > Decimal.zero ? ' × ${formatDecimal(profileFactor)} fire' : ''}'
              ' = ${m(meters)}',
            );
            lines.add(
              CostLine(
                label: '$label – ${c.name}',
                description: 'Reçete: ${recipe.name}$tag',
                kind: CostKind.material,
                quantity: meters,
                unit: 'm',
                unitPrice: c.pricePerMeter,
              ),
            );
          }
          if (!recipe.verified) {
            warnings.add(
              '$label: "${recipe.name}" profil reçetesi doğrulanmamış. '
              'Kesim payları açılım türüne ve üretici sistemine göre '
              'değişir; profil metrajı tahminidir.',
            );
          }
      }

      // Aksesuar ve mekanizma
      if (item.accessoryPricePerUnit case final price?) {
        requireNonNegativePrice(price, '$label aksesuar fiyatı');
        lines.add(
          CostLine(
            label: '$label – Aksesuar ve mekanizma',
            kind: CostKind.accessory,
            quantity: q,
            unit: 'adet',
            unitPrice: price,
          ),
        );
      }

      // Sineklik
      if (item.flyScreen) {
        final price = item.flyScreenPricePerUnit;
        if (price == null) {
          warnings.add('$label: sineklik seçildi ancak fiyatı girilmedi.');
        } else {
          requireNonNegativePrice(price, '$label sineklik fiyatı');
          lines.add(
            CostLine(
              label: '$label – Sineklik',
              kind: CostKind.accessory,
              quantity: q,
              unit: 'adet',
              unitPrice: price,
            ),
          );
        }
      }
    }

    if (input.items.length > 1) {
      steps.add('Toplam doğrama alanı = ${m(totalArea, 'm²')}');
    }

    final figures = [
      ResultFigure(
        label: 'Toplam doğrama alanı',
        value: totalArea,
        unit: 'm²',
        highlighted: true,
      ),
      if (totalGlass > Decimal.zero)
        ResultFigure(
          label: glassWaste > Decimal.zero
              ? 'Cam alanı (${formatPercent(glassWaste)} fireli)'
              : 'Cam alanı',
          value: totalGlass,
          unit: 'm²',
        ),
      if (totalProfile > Decimal.zero)
        ResultFigure(
          label: profileWaste > Decimal.zero
              ? 'Profil metrajı (${formatPercent(profileWaste)} fireli)'
              : 'Profil metrajı',
          value: totalProfile,
          unit: 'm',
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

/// PVC doğrama için hazır ek kalem şablonları.
abstract final class PvcCatalog {
  static const List<CostTemplate> extras = [
    CostTemplate(
      name: 'Montaj',
      category: CostKind.labor,
      unit: CostUnit.squareMeter,
    ),
    CostTemplate(
      name: 'Nakliye',
      category: CostKind.shipping,
      unit: CostUnit.service,
    ),
    CostTemplate(
      name: 'Eski doğrama sökümü',
      category: CostKind.labor,
      unit: CostUnit.piece,
    ),
  ];

  /// Başlangıç reçetesi: yalnızca kasa çevresi (2 × En + 2 × Boy).
  /// Fiyatı ve diğer bileşenleri kullanıcı tamamlar; doğrulanmamıştır.
  static ProfileRecipe starterRecipe(String id) => ProfileRecipe(
    id: id,
    name: 'Yeni reçete',
    components: [
      ProfileComponent(
        name: 'Kasa',
        role: ProfileRole.frame,
        widthFactor: Decimal.fromInt(2),
        heightFactor: Decimal.fromInt(2),
        pricePerMeter: Money.zero,
      ),
    ],
  );
}
