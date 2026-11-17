import 'package:decimal/decimal.dart';

import '../../engine/calculation_result.dart';
import '../../engine/calculator.dart';
import '../../engine/calculators/marble_countertop_calculator.dart';
import '../../engine/calculators/measurement_calculator.dart';
import '../../engine/costing/cost_sheet.dart';
import '../../engine/measurement.dart';
import '../../engine/money.dart';
import '../../engine/number_parser.dart';
import '../../engine/pricing.dart';

/// Hesaplama ekranındaki giriş alanları.
enum CalcField {
  length,
  width,
  height,
  quantity,
  manualAmount,
  waste,
  unitPrice,
  materialPrice,
  laborPrice,
  vat,
}

/// Hesaplama ekranında seçilebilen hesap türleri.
enum CalcMode {
  marbleCountertop('Tek parça tezgâh', null),
  length('Uzunluk', MeasurementType.length),
  area('Alan (m²)', MeasurementType.area),
  volume('Hacim (m³)', MeasurementType.volume),
  linearMeter('Metre tül', MeasurementType.linearMeter),
  perimeter('Çevre', MeasurementType.perimeter),
  piece('Adet', MeasurementType.piece),
  manual('Manuel', MeasurementType.manual);

  const CalcMode(this.label, this.measurementType);

  final String label;
  final MeasurementType? measurementType;

  bool get usesLengthUnit =>
      this == marbleCountertop || (measurementType?.usesLengthUnit ?? false);

  /// Bu modda gösterilecek alanlar (sırasıyla).
  List<CalcField> get fields {
    if (this == marbleCountertop) {
      return const [
        CalcField.length,
        CalcField.width,
        CalcField.quantity,
        CalcField.waste,
        CalcField.materialPrice,
        CalcField.laborPrice,
      ];
    }
    final t = measurementType!;
    return [
      if (t.needsLength) CalcField.length,
      if (t.needsWidth) CalcField.width,
      if (t.needsHeight) CalcField.height,
      if (t == MeasurementType.manual) CalcField.manualAmount,
      CalcField.quantity,
      CalcField.waste,
      CalcField.unitPrice,
    ];
  }

  String fieldLabel(CalcField field) => switch (field) {
    CalcField.length => 'Uzunluk',
    CalcField.width => this == marbleCountertop ? 'Derinlik' : 'Genişlik',
    CalcField.height => 'Yükseklik',
    CalcField.quantity => 'Adet',
    CalcField.manualAmount => 'Miktar',
    CalcField.waste => 'Fire',
    CalcField.unitPrice =>
      'Birim fiyat (₺/${measurementType?.unitSymbol ?? ''})',
    CalcField.materialPrice => 'Malzeme fiyatı (₺/m²)',
    CalcField.laborPrice => 'İşçilik fiyatı (₺/mtül)',
    CalcField.vat => 'KDV',
  };
}

/// Meslek kategorisine göre sunulan hesap türleri. Özel hesabı olan
/// kategorilerde özel hesap ilk sıradadır.
List<CalcMode> modesForCategory(String? categoryId) => [
  if (categoryId == 'marble_granite') CalcMode.marbleCountertop,
  for (final m in CalcMode.values)
    if (m != CalcMode.marbleCountertop) m,
];

/// Form değerlendirmesinin sonucu.
final class FormEvaluation {
  const FormEvaluation({
    this.result,
    this.fieldErrors = const {},
    this.message,
  });

  final CalculationResult? result;

  /// Alan bazlı hatalar (ör. geçersiz sayı).
  final Map<CalcField, String> fieldErrors;

  /// Sonuç üretilemediğinde kullanıcıya gösterilecek açıklama.
  final String? message;
}

const invalidNumberMessage = 'Geçerli bir sayı girin (ör. 1.250,75)';

/// Ham metin girişlerini doğrular, motora uygun girdiye çevirir ve hesaplar.
///
/// Arayüzden bağımsızdır; tüm sayılar [Decimal] olarak işlenir.
FormEvaluation evaluateForm({
  required CalcMode mode,
  required LengthUnit unit,
  required Map<CalcField, String> values,
  CostSheet extras = const CostSheet(),
  Discount? discount,
}) {
  final errors = <CalcField, String>{};
  final parsed = <CalcField, Decimal?>{};

  // KDV, fiyatlandırma bölümünden gelir ve her modda geçerlidir.
  for (final field in [...mode.fields, CalcField.vat]) {
    final raw = (values[field] ?? '').trim();
    if (raw.isEmpty) {
      parsed[field] = null;
      continue;
    }
    final value = parseDecimal(raw);
    if (value == null) {
      errors[field] = invalidNumberMessage;
    } else if (value < Decimal.zero) {
      errors[field] = 'Negatif değer girilemez';
    } else {
      parsed[field] = value;
    }
  }

  var quantity = 1;
  final q = parsed[CalcField.quantity];
  if (q != null) {
    if (!q.isInteger || q < Decimal.one) {
      errors[CalcField.quantity] = 'Adet 1 veya daha büyük tam sayı olmalı';
    } else {
      quantity = q.toBigInt().toInt();
    }
  }

  if (errors.isNotEmpty) {
    return FormEvaluation(
      fieldErrors: errors,
      message: 'Hatalı alanları düzeltin.',
    );
  }

  Money? money(CalcField f) =>
      parsed[f] == null ? null : Money.fromDecimal(parsed[f]!);

  try {
    final CalculationResult result;
    if (mode == CalcMode.marbleCountertop) {
      result = const MarbleCountertopCalculator().calculate(
        MarbleCountertopInput(
          unit: unit,
          length: parsed[CalcField.length],
          depth: parsed[CalcField.width],
          quantity: quantity,
          wastePercent: parsed[CalcField.waste],
          materialPricePerSquareMeter: money(CalcField.materialPrice),
          laborPricePerLinearMeter: money(CalcField.laborPrice),
          vatPercent: parsed[CalcField.vat],
          extras: extras,
          discount: discount,
        ),
      );
    } else {
      result = const MeasurementCalculator().calculate(
        MeasurementInput(
          type: mode.measurementType!,
          unit: unit,
          length: parsed[CalcField.length],
          width: parsed[CalcField.width],
          height: parsed[CalcField.height],
          quantity: quantity,
          manualAmount: parsed[CalcField.manualAmount],
          wastePercent: parsed[CalcField.waste],
          unitPrice: money(CalcField.unitPrice),
          vatPercent: parsed[CalcField.vat],
          extras: extras,
          discount: discount,
        ),
      );
    }
    return FormEvaluation(result: result);
  } on CalculationException catch (e) {
    return FormEvaluation(message: e.message);
  }
}
