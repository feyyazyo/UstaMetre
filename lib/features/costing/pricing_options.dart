import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../engine/calculator.dart';
import '../../engine/money.dart';
import '../../engine/pricing.dart';
import '../../shared/input_parsing.dart';
import '../calculations/widgets/number_field.dart';

enum DiscountMode {
  none('İndirim yok'),
  percent('Yüzde (%)'),
  amount('Tutar (₺)');

  const DiscountMode(this.label);

  final String label;
}

/// KDV oranı, indirim ve KDV dahil/hariç gösterim ayarları.
class PricingOptionsController extends ChangeNotifier {
  PricingOptionsController({String vat = '20'}) {
    this.vat.text = vat;
    this.vat.addListener(notifyListeners);
    discountValue.addListener(notifyListeners);
  }

  final vat = TextEditingController();
  final discountValue = TextEditingController();
  DiscountMode _discountMode = DiscountMode.none;
  VatDisplayMode _display = VatDisplayMode.excluded;

  DiscountMode get discountMode => _discountMode;
  set discountMode(DiscountMode value) {
    _discountMode = value;
    notifyListeners();
  }

  VatDisplayMode get display => _display;
  set display(VatDisplayMode value) {
    _display = value;
    notifyListeners();
  }

  ParsedField<Decimal> get vatPercent => parseField(vat.text);

  /// İndirim kuralı; geçersizse `error` dolu döner.
  ParsedField<Discount> get discount {
    if (_discountMode == DiscountMode.none) return (value: null, error: null);
    final p = parseField(discountValue.text);
    if (p.error != null || p.value == null) {
      return (value: null, error: p.error);
    }
    try {
      return (
        value: _discountMode == DiscountMode.percent
            ? PercentDiscount(p.value!)
            : AmountDiscount(Money.fromDecimal(p.value!)),
        error: null,
      );
    } on CalculationException catch (e) {
      return (value: null, error: e.message);
    }
  }

  String? get error => vatPercent.error ?? discount.error;

  @override
  void dispose() {
    vat.dispose();
    discountValue.dispose();
    super.dispose();
  }
}

/// Fiyatlandırma bölümü: KDV oranı, indirim, KDV dahil/hariç gösterim.
class PricingOptionsSection extends StatelessWidget {
  const PricingOptionsSection({super.key, required this.controller});

  final PricingOptionsController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NumberField(
            key: const ValueKey('field_vat'),
            controller: controller.vat,
            label: 'KDV oranı',
            suffix: '%',
            errorText: controller.vatPercent.error,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DiscountMode>(
            isExpanded: true,
            key: const ValueKey('discount_mode'),
            initialValue: controller.discountMode,
            dropdownColor: AppColors.card,
            decoration: const InputDecoration(labelText: 'İndirim'),
            items: [
              for (final m in DiscountMode.values)
                DropdownMenuItem(value: m, child: Text(m.label)),
            ],
            onChanged: (m) => controller.discountMode = m!,
          ),
          if (controller.discountMode != DiscountMode.none) ...[
            const SizedBox(height: 12),
            NumberField(
              key: const ValueKey('field_discount'),
              controller: controller.discountValue,
              label: controller.discountMode == DiscountMode.percent
                  ? 'İndirim oranı'
                  : 'İndirim tutarı',
              suffix: controller.discountMode == DiscountMode.percent
                  ? '%'
                  : '₺',
              errorText: controller.discount.error,
            ),
          ],
          const SizedBox(height: 12),
          SegmentedButton<VatDisplayMode>(
            key: const ValueKey('vat_display'),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              selectedBackgroundColor: AppColors.gold,
              selectedForegroundColor: AppColors.onGold,
            ),
            segments: [
              for (final m in VatDisplayMode.values)
                ButtonSegment(
                  value: m,
                  label: Text(m.label, key: ValueKey('vat_display_${m.name}')),
                ),
            ],
            selected: {controller.display},
            onSelectionChanged: (s) => controller.display = s.first,
          ),
        ],
      ),
    );
  }
}
