import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/calculation_result.dart';
import 'package:ustametre/engine/calculator.dart';
import 'package:ustametre/engine/calculators/pvc_joinery_calculator.dart';
import 'package:ustametre/engine/costing/cost_sheet.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/engine/pricing.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);
  Money tl(String s) => Money.fromDecimal(d(s));
  const calc = PvcJoineryCalculator();

  Decimal fig(CalculationResult r, String label) =>
      r.figures.firstWhere((f) => f.label.startsWith(label)).value;
  Money line(CalculationResult r, String label) =>
      r.price!.lines.firstWhere((l) => l.label == label).amount;

  final window = JoineryItem(
    id: 'w',
    type: JoineryType.window,
    width: d('120'),
    height: d('150'),
    quantity: 2,
  );
  final balcony = JoineryItem(
    id: 'b',
    type: JoineryType.balconyDoor,
    name: 'Salon balkon kapısı',
    width: d('90'),
    height: d('220'),
  );

  final recipe = ProfileRecipe(
    id: 'r1',
    name: 'Tek kanat',
    components: [
      ProfileComponent(
        name: 'Kasa',
        role: ProfileRole.frame,
        widthFactor: d('2'),
        heightFactor: d('2'),
        pricePerMeter: tl('180'),
      ),
      ProfileComponent(
        name: 'Kanat',
        role: ProfileRole.sash,
        widthFactor: d('2'),
        heightFactor: d('2'),
        offsetMeters: d('-0.2'),
        pricePerMeter: tl('210'),
      ),
    ],
  );

  group('Alan', () {
    test('birden fazla doğrama kalemi ve adet', () {
      final r = calc.calculate(PvcProjectInput(items: [window, balcony]));
      // 1,2 × 1,5 × 2 = 3,6 + 0,9 × 2,2 = 1,98
      expect(fig(r, 'Toplam doğrama alanı'), d('5.58'));
      expect(r.price, isNull);
      expect(r.steps.first, 'Pencere 1: 1,2 m × 1,5 m × 2 adet = 3,6 m²');
      expect(
        r.steps[1],
        startsWith('Salon balkon kapısı (Balkon kapısı): 0,9 m × 2,2 m'),
      );
    });
  });

  group('Doğrama türü', () {
    test('tür bazında numaralama ve adlı kalemde tür etiketi', () {
      final labels = joineryLabels([
        window,
        JoineryItem(id: 'd', type: JoineryType.door),
        window,
        balcony,
      ]);
      expect(labels, [
        'Pencere 1',
        'Kapı 1',
        'Pencere 2',
        'Salon balkon kapısı (Balkon kapısı)',
      ]);
    });

    test('her tür için adet ve alan ayrı gösterilir', () {
      final r = calc.calculate(
        PvcProjectInput(
          items: [
            window,
            JoineryItem(
              id: 'd',
              type: JoineryType.door,
              width: d('90'),
              height: d('210'),
            ),
            balcony,
          ],
        ),
      );
      expect(fig(r, 'Pencere (2 adet)'), d('3.6'));
      expect(fig(r, 'Kapı (1 adet)'), d('1.89'));
      expect(fig(r, 'Balkon kapısı (1 adet)'), d('1.98'));
      expect(fig(r, 'Toplam doğrama alanı'), d('7.47'));
    });

    test('tür değişince etiketler ve tür toplamları güncellenir', () {
      final asWindow = calc.calculate(
        PvcProjectInput(
          items: [window.copyWith(glassPricePerSquareMeter: tl('100'))],
        ),
      );
      final asBalcony = calc.calculate(
        PvcProjectInput(
          items: [
            window.copyWith(
              type: JoineryType.balconyDoor,
              glassPricePerSquareMeter: tl('100'),
            ),
          ],
        ),
      );
      expect(asWindow.price!.lines.single.label, 'Pencere 1 – Cam');
      expect(asBalcony.price!.lines.single.label, 'Balkon kapısı 1 – Cam');
      expect(fig(asBalcony, 'Balkon kapısı (2 adet)'), d('3.6'));
      expect(
        asBalcony.figures.where((f) => f.label.startsWith('Pencere')),
        isEmpty,
      );
      // Ölçüye bağlı tutar türden bağımsızdır (aynı ölçü → aynı cam).
      expect(asBalcony.price!.subtotal, asWindow.price!.subtotal);
      // Tür, PDF/kayıt için dışa aktarılan veride de görünür.
      expect(asBalcony.toJson().toString(), contains('Balkon kapısı'));
    });
  });

  group('Cam', () {
    test('ölçülen cam alanı + cam firesi, uyarı yok', () {
      final r = calc.calculate(
        PvcProjectInput(
          glassWastePercent: d('5'),
          items: [
            window.copyWith(
              glassType: 'Isıcam 4+16+4',
              glassPricePerSquareMeter: tl('950'),
              glassAreaPerUnit: d('1.45'),
            ),
          ],
        ),
      );
      expect(fig(r, 'Cam alanı'), d('3.045')); // 1,45 × 2 × 1,05
      expect(line(r, 'Pencere 1 – Cam (Isıcam 4+16+4)'), tl('2892.75'));
      expect(r.warnings, isEmpty);
    });

    test('cam alanı girilmezse dış ölçü kullanılır ve uyarılır', () {
      final r = calc.calculate(
        PvcProjectInput(
          items: [window.copyWith(glassPricePerSquareMeter: tl('950'))],
        ),
      );
      expect(fig(r, 'Cam alanı'), d('3.6'));
      expect(line(r, 'Pencere 1 – Cam'), tl('3420'));
      expect(r.warnings.single, contains('dış ölçüden alındı'));
    });
  });

  group('Profil', () {
    test('manuel profil metrajı ve profil firesi', () {
      final r = calc.calculate(
        PvcProjectInput(
          profileWastePercent: d('10'),
          items: [
            window.copyWith(
              profile: ManualProfile(
                metersPerUnit: d('9.4'),
                pricePerMeter: tl('185.5'),
              ),
            ),
          ],
        ),
      );
      expect(fig(r, 'Profil metrajı'), d('20.68')); // 9,4 × 2 × 1,1
      expect(line(r, 'Pencere 1 – Profil'), tl('3836.14')); // 20,68 × 185,5
      expect(r.warnings, isEmpty);
    });

    test('reçete: kasa ve kanat ayrı satır, doğrulanmamışsa tahmini', () {
      final r = calc.calculate(
        PvcProjectInput(
          items: [window.copyWith(profile: RecipeProfile(recipe))],
        ),
      );
      // Kasa: 2×1,2 + 2×1,5 = 5,4 m × 2 adet = 10,8 m
      // Kanat: 5,4 − 0,2 = 5,2 m × 2 adet = 10,4 m
      expect(line(r, 'Pencere 1 – Kasa'), tl('1944')); // 10,8 × 180
      expect(line(r, 'Pencere 1 – Kanat'), tl('2184')); // 10,4 × 210
      expect(fig(r, 'Profil metrajı'), d('21.2'));
      expect(r.warnings.single, contains('doğrulanmamış'));
      expect(
        r.steps,
        contains(
          'Pencere 1 Kanat (tahmini): 2 × En + 2 × Boy − 0,2 m = 5,2 m '
          '× 2 adet = 10,4 m',
        ),
      );
      expect(
        r.price!.lines
            .firstWhere((l) => l.label == 'Pencere 1 – Kasa')
            .description,
        'Reçete: Tek kanat (tahmini)',
      );
    });

    test('doğrulanmış reçetede uyarı yok', () {
      final r = calc.calculate(
        PvcProjectInput(
          items: [
            window.copyWith(
              profile: RecipeProfile(recipe.copyWith(verified: true)),
            ),
          ],
        ),
      );
      expect(r.warnings, isEmpty);
      expect(r.steps.join(), isNot(contains('tahmini')));
    });

    test('negatif sonuç veren formül reddedilir', () {
      final bad = recipe.copyWith(
        components: [
          ProfileComponent(
            name: 'Çıta',
            role: ProfileRole.glazingBead,
            widthFactor: d('0'),
            heightFactor: d('0'),
            offsetMeters: d('-1'),
            pricePerMeter: tl('10'),
          ),
        ],
      );
      expect(
        () => calc.calculate(
          PvcProjectInput(
            items: [window.copyWith(profile: RecipeProfile(bad))],
          ),
        ),
        throwsA(isA<CalculationException>()),
      );
    });

    test('reçete JSON gidiş-dönüş', () {
      final back = ProfileRecipe.fromJson(recipe.toJson());
      expect(back.toJson(), recipe.toJson());
      expect(back.components[1].formula, '2 × En + 2 × Boy − 0,2 m');
    });
  });

  group('Aksesuar, sineklik, montaj, nakliye, indirim, KDV', () {
    test('tam doğrama teklifi', () {
      var extras = const CostSheet();
      final prices = {
        'Montaj': ('5.58', '250'),
        'Nakliye': ('1', '1000'),
        'Eski doğrama sökümü': ('3', '150'),
      };
      for (final (i, t) in PvcCatalog.extras.indexed) {
        final (qty, price) = prices[t.name]!;
        extras = extras.add(
          t.toItem(id: 'e$i', quantity: d(qty), unitPrice: tl(price)),
        );
      }
      final r = calc.calculate(
        PvcProjectInput(
          vatPercent: d('20'),
          discount: AmountDiscount(tl('500')),
          extras: extras,
          items: [
            window.copyWith(
              glassPricePerSquareMeter: tl('950'),
              glassAreaPerUnit: d('1.45'),
              profile: ManualProfile(
                metersPerUnit: d('9.4'),
                pricePerMeter: tl('185.5'),
              ),
              accessoryPricePerUnit: tl('1250'),
              flyScreen: true,
              flyScreenPricePerUnit: tl('400'),
            ),
            balcony.copyWith(
              glassPricePerSquareMeter: tl('950'),
              glassAreaPerUnit: d('1.6'),
              accessoryPricePerUnit: tl('2100'),
            ),
          ],
        ),
      );
      final p = r.price!;
      // Cam: 2,9 × 950 = 2755 + 1,6 × 950 = 1520 → 4275
      // Profil: 18,8 × 185,5 = 3487,4
      expect(p.totalOf(CostKind.material), tl('7762.4'));
      // Aksesuar: 2 × 1250 + 2 × 400 + 2100 = 5400
      expect(p.totalOf(CostKind.accessory), tl('5400'));
      // İşçilik: 5,58 × 250 = 1395 + 450 = 1845
      expect(p.totalOf(CostKind.labor), tl('1845'));
      expect(p.totalOf(CostKind.shipping), tl('1000'));
      expect(p.subtotal, tl('16007.4'));
      expect(p.taxBase, tl('15507.4'));
      expect(p.vat, tl('3101.48'));
      expect(p.grandTotal, tl('18608.88'));
    });

    test('fiyatsız sineklik uyarı verir, tutara eklenmez', () {
      final r = calc.calculate(
        PvcProjectInput(items: [window.copyWith(flyScreen: true)]),
      );
      expect(r.warnings.single, contains('sineklik'));
      expect(r.price, isNull);
    });
  });

  group('Hatalı ve boş girişler', () {
    void rejects(PvcProjectInput input, String message) => expect(
      () => calc.calculate(input),
      throwsA(
        isA<CalculationException>().having(
          (e) => e.message,
          'message',
          message,
        ),
      ),
    );

    test('kalem yok / ölçü eksik / adet sıfır', () {
      rejects(
        const PvcProjectInput(items: []),
        'En az bir doğrama kalemi ekleyin.',
      );
      rejects(
        PvcProjectInput(items: [window.copyWith(quantity: 0)]),
        'Adet en az 1 olmalıdır.',
      );
      rejects(
        const PvcProjectInput(
          items: [JoineryItem(id: 'x', type: JoineryType.door)],
        ),
        'Kapı 1 eni girin.',
      );
    });

    test('negatif fiyat ve sıfır cam alanı', () {
      rejects(
        PvcProjectInput(
          items: [window.copyWith(glassPricePerSquareMeter: tl('-1'))],
        ),
        'Pencere 1 cam fiyatı negatif olamaz.',
      );
      rejects(
        PvcProjectInput(
          items: [
            window.copyWith(
              glassPricePerSquareMeter: tl('1'),
              glassAreaPerUnit: d('0'),
            ),
          ],
        ),
        'Pencere 1 cam alanı sıfırdan büyük olmalıdır.',
      );
    });
  });
}
