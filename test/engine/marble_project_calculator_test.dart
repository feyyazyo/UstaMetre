import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustametre/engine/calculation_result.dart';
import 'package:ustametre/engine/calculator.dart';
import 'package:ustametre/engine/calculators/marble_project_calculator.dart';
import 'package:ustametre/engine/costing/cost_sheet.dart';
import 'package:ustametre/engine/measurement.dart';
import 'package:ustametre/engine/money.dart';
import 'package:ustametre/engine/pricing.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);
  Money tl(String s) => Money.fromDecimal(d(s));
  const calc = MarbleProjectCalculator();

  Decimal fig(CalculationResult r, String label) =>
      r.figures.firstWhere((f) => f.label.startsWith(label)).value;
  Money line(CalculationResult r, String label) =>
      r.price!.lines.firstWhere((l) => l.label == label).amount;

  // L tezgâh: ana tezgâh 250×62 cm + yan tezgâh 120×62 cm.
  final main = CountertopPiece(
    id: 'p1',
    name: 'Ana tezgâh',
    length: d('250'),
    depth: d('62'),
  );
  final side = CountertopPiece(
    id: 'p2',
    name: 'Yan tezgâh',
    length: d('120'),
    depth: d('62'),
  );

  group('Çok parçalı tezgâh', () {
    test('alan ve tezgâh uzunluğu parçaların toplamıdır', () {
      final r = calc.calculate(MarbleProjectInput(pieces: [main, side]));
      expect(fig(r, 'Net alan'), d('2.294')); // 1,55 + 0,744
      expect(fig(r, 'Tezgâh uzunluğu'), d('3.7'));
      expect(
        r.steps.first,
        'Ana tezgâh: 250 × 62 cm = 2,5 m × 0,62 m = 1,55 m²',
      );
      expect(r.steps, contains('Toplam net alan = 2,294 m²'));
    });

    test('parça adedi alan, uzunluk ve kenarlara yansır', () {
      final r = calc.calculate(
        MarbleProjectInput(
          unit: LengthUnit.millimeter,
          pieces: [
            CountertopPiece(
              id: 'p',
              name: 'Denizlik',
              length: d('1200'),
              depth: d('300'),
              quantity: 4,
            ).toggleEdge(EdgeOperation.pah, CountertopEdge.front),
          ],
        ),
      );
      expect(fig(r, 'Net alan'), d('1.44'));
      expect(fig(r, 'Tezgâh uzunluğu'), d('4.8'));
      expect(fig(r, 'Pah'), d('4.8'));
    });

    test('fire yalnızca malzemeye uygulanır; işçilik net ölçüden', () {
      final r = calc.calculate(
        MarbleProjectInput(
          pieces: [main, side],
          materialWastePercent: d('15'),
          materialPricePerSquareMeter: tl('3200'),
          countertopLaborPerLinearMeter: tl('450'),
        ),
      );
      expect(fig(r, 'Fireli alan'), d('2.6381')); // 2,294 × 1,15
      expect(line(r, 'Malzeme'), tl('8441.92')); // 2,6381 × 3200
      expect(line(r, 'Tezgâh işçiliği'), tl('1665')); // 3,7 × 450
    });
  });

  group('Kenar işlemleri (metre tül)', () {
    test('seçilen kenarların uzunlukları toplanır', () {
      final p1 = main
          .toggleEdge(EdgeOperation.sakal, CountertopEdge.front)
          .toggleEdge(EdgeOperation.pah, CountertopEdge.front)
          .toggleEdge(EdgeOperation.pah, CountertopEdge.left)
          .toggleEdge(EdgeOperation.rodaj, CountertopEdge.front);
      final p2 = side
          .toggleEdge(EdgeOperation.sakal, CountertopEdge.front)
          .toggleEdge(EdgeOperation.sakal, CountertopEdge.right)
          .toggleEdge(EdgeOperation.edgeFinish, CountertopEdge.back);
      final r = calc.calculate(
        MarbleProjectInput(
          pieces: [p1, p2],
          edgePrices: {
            EdgeOperation.sakal: tl('350'),
            EdgeOperation.pah: tl('120'),
            EdgeOperation.rodaj: tl('90'),
            EdgeOperation.edgeFinish: tl('75.5'),
          },
        ),
      );
      expect(fig(r, 'Sakal'), d('4.32')); // 2,5 + 1,2 + 0,62
      expect(fig(r, 'Pah'), d('3.12')); // 2,5 + 0,62
      expect(fig(r, 'Rodaj'), d('2.5'));
      expect(fig(r, 'Kenar işleme'), d('1.2'));
      expect(line(r, 'Sakal'), tl('1512')); // 4,32 × 350
      expect(line(r, 'Pah'), tl('374.4'));
      expect(line(r, 'Rodaj'), tl('225'));
      expect(line(r, 'Kenar işleme'), tl('90.6'));
      expect(
        r.steps,
        contains(
          'Sakal = Ana tezgâh ön (2,5 m) + Yan tezgâh ön (1,2 m) + '
          'Yan tezgâh sağ (0,62 m) = 4,32 mtül',
        ),
      );
    });

    test('kenar seçimi geri alınabilir', () {
      final p = main
          .toggleEdge(EdgeOperation.sakal, CountertopEdge.front)
          .toggleEdge(EdgeOperation.sakal, CountertopEdge.front);
      final r = calc.calculate(
        MarbleProjectInput(
          pieces: [p],
          edgePrices: {EdgeOperation.sakal: tl('350')},
        ),
      );
      expect(r.figures.where((f) => f.label == 'Sakal'), isEmpty);
      expect(r.price, isNull);
    });

    test('fiyatı girilmemiş işlem için uyarı verilir', () {
      final r = calc.calculate(
        MarbleProjectInput(
          pieces: [main.toggleEdge(EdgeOperation.rodaj, CountertopEdge.front)],
        ),
      );
      expect(r.warnings.single, startsWith('Rodaj kenarları seçildi'));
    });
  });

  group('Evye ve ek kalemler', () {
    test('evye, ocak, batarya, nakliye ve montaj toplamlara eklenir', () {
      var extras = const CostSheet();
      final prices = {
        'Evye bedeli': ('1', '2400'),
        'Evye montajı': ('1', '750'),
        'Evye kesim ve işleme': ('1', '600'),
        'Ocak kesimi': ('1', '500'),
        'Batarya deliği': ('2', '150'),
        'Diğer delik işlemleri': ('1', '100'),
        'Nakliye': ('1', '800'),
        'Montaj': ('3.7', '200'),
      };
      for (final (i, t) in MarbleCatalog.extras.indexed) {
        final (qty, price) = prices[t.name]!;
        extras = extras.add(
          t.toItem(id: 'e$i', quantity: d(qty), unitPrice: tl(price)),
        );
      }
      final r = calc.calculate(
        MarbleProjectInput(
          pieces: [main, side],
          materialWastePercent: d('10'),
          materialPricePerSquareMeter: tl('3200'),
          countertopLaborPerLinearMeter: tl('450'),
          extras: extras,
          vatPercent: d('20'),
          discount: PercentDiscount(d('5')),
        ),
      );
      final p = r.price!;
      // Malzeme: 2,294 × 1,1 = 2,5234 m² × 3200 = 8074,88
      expect(line(r, 'Malzeme'), tl('8074.88'));
      expect(p.totalOf(CostKind.material), tl('8074.88'));
      expect(p.totalOf(CostKind.accessory), tl('2400'));
      // İşçilik: 1665 + 750 + 600 + 500 + 300 + 100 + 740 = 4655
      expect(p.totalOf(CostKind.labor), tl('4655'));
      expect(p.totalOf(CostKind.shipping), tl('800'));
      expect(p.subtotal, tl('15929.88'));
      expect(p.discount, tl('796.49')); // 796,494
      expect(p.taxBase, tl('15133.39'));
      expect(p.vat, tl('3026.68')); // 3026,678
      expect(p.grandTotal, tl('18160.07'));
    });
  });

  group('Hatalı ve boş girişler', () {
    void rejects(MarbleProjectInput input, String message) => expect(
      () => calc.calculate(input),
      throwsA(
        isA<CalculationException>().having(
          (e) => e.message,
          'message',
          message,
        ),
      ),
    );

    test('parça yok', () {
      rejects(
        const MarbleProjectInput(pieces: []),
        'En az bir tezgâh parçası ekleyin.',
      );
    });

    test('eksik ölçü parça adıyla bildirilir', () {
      rejects(
        MarbleProjectInput(
          pieces: [
            main,
            side.copyWith(depth: d('0')),
          ],
        ),
        'Yan tezgâh derinliği sıfırdan büyük olmalıdır.',
      );
      rejects(
        const MarbleProjectInput(
          pieces: [CountertopPiece(id: 'x', name: '')],
        ),
        'Parça 1 uzunluğu girin.',
      );
    });

    test('sıfır adet ve aralık dışı fire', () {
      rejects(
        MarbleProjectInput(pieces: [main.copyWith(quantity: 0)]),
        'Adet en az 1 olmalıdır.',
      );
      rejects(
        MarbleProjectInput(pieces: [main], materialWastePercent: d('101')),
        'Malzeme firesi %0 ile %100 arasında olmalıdır.',
      );
    });
  });
}
