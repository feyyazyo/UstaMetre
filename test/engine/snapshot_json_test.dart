import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/calculation_result.dart';
import 'package:ustametre/engine/calculators/marble_project_calculator.dart';
import 'package:ustametre/engine/calculators/measurement_calculator.dart';
import 'package:ustametre/engine/calculators/pvc_joinery_calculator.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/engine/pricing.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);
  Money tl(String s) => Money.fromDecimal(d(s));

  test('sonuç JSON gidiş-dönüş: tüm tutarlar, satırlar ve adımlar aynı', () {
    final r = const MeasurementCalculator().calculate(
      MeasurementInput(
        type: MeasurementType.area,
        length: d('2.5'),
        width: d('0.62'),
        wastePercent: d('10'),
        unitPrice: tl('3200'),
        vatPercent: d('20'),
        discount: AmountDiscount(tl('100')),
      ),
    );
    final json = jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>;
    final back = CalculationResult.fromJson(json);
    expect(back.toJson(), r.toJson());
    expect(back.price!.grandTotal, r.price!.grandTotal);
    expect(back.price!.discountRule, isA<AmountDiscount>());
    expect(back.steps, r.steps);
  });

  test('geri yükleme tutarları yeniden hesaplamaz (kayıt anındaki değer)', () {
    final r = const MeasurementCalculator().calculate(
      MeasurementInput(
        type: MeasurementType.piece,
        quantity: 3,
        unitPrice: tl('33.33'),
        vatPercent: d('20'),
      ),
    );
    final json = jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>;
    // Kayıttaki değerler farklı bir kuralla hesaplanmış olsaydı bile
    // olduğu gibi okunmalı:
    final price = json['price']! as Map<String, Object?>;
    price['vatKurus'] = '2000';
    price['grandTotalKurus'] = '11999';
    final back = CalculationResult.fromJson(json);
    expect(back.price!.vat, Money.fromKurus(2000));
    expect(back.price!.grandTotal, Money.fromKurus(11999));
  });

  test('tezgâh parçası JSON gidiş-dönüş (kenarlar dahil)', () {
    final p =
        CountertopPiece(
              id: 'p1',
              name: 'Ada',
              length: d('180.5'),
              depth: d('90'),
              quantity: 2,
            )
            .toggleEdge(EdgeOperation.sakal, CountertopEdge.front)
            .toggleEdge(EdgeOperation.pah, CountertopEdge.left)
            .toggleEdge(EdgeOperation.pah, CountertopEdge.right);
    final back = CountertopPiece.fromJson(
      jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>,
    );
    expect(back.toJson(), p.toJson());
    expect(back.edgesFor(EdgeOperation.pah), {
      CountertopEdge.left,
      CountertopEdge.right,
    });
  });

  test('doğrama kalemi JSON gidiş-dönüş (manuel ve reçeteli profil)', () {
    final recipe = ProfileRecipe(
      id: 'r',
      name: 'Tek kanat',
      components: [
        ProfileComponent(
          name: 'Kasa',
          role: ProfileRole.frame,
          widthFactor: d('2'),
          heightFactor: d('2'),
          offsetMeters: d('-0.1'),
          pricePerMeter: tl('180'),
        ),
      ],
    );
    for (final profile in [
      ManualProfile(metersPerUnit: d('9.4'), pricePerMeter: tl('185.5')),
      RecipeProfile(recipe),
    ]) {
      final item = JoineryItem(
        id: 'j',
        type: JoineryType.balconyDoor,
        name: 'Salon',
        width: d('90'),
        height: d('220'),
        quantity: 2,
        glassType: 'Isıcam',
        glassPricePerSquareMeter: tl('950'),
        glassAreaPerUnit: d('1.6'),
        profile: profile,
        accessoryPricePerUnit: tl('2100'),
        flyScreen: true,
        flyScreenPricePerUnit: tl('400'),
      );
      final back = JoineryItem.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, Object?>,
      );
      expect(back.toJson(), item.toJson());
      final a = const PvcJoineryCalculator().calculate(
        PvcProjectInput(items: [item]),
      );
      final b = const PvcJoineryCalculator().calculate(
        PvcProjectInput(items: [back]),
      );
      expect(b.price!.grandTotal, a.price!.grandTotal);
    }
  });
}
