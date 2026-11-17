import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../engine/calculation_result.dart';
import '../../../engine/money.dart';
import '../../../engine/number_format.dart';
import '../../../engine/pricing.dart';

/// Hesap sonucunu, fiyat özetini, uyarıları ve "Nasıl hesaplandı?"
/// adımlarını gösterir.
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.result,
    this.display = VatDisplayMode.excluded,
  });

  final CalculationResult result;

  /// Satır tutarlarının KDV dahil mi hariç mi gösterileceği. Toplamlar her
  /// iki modda da açıkça ayrılır.
  final VatDisplayMode display;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = result.price;
    final included = display == VatDisplayMode.included;

    return Card(
      key: const ValueKey('result_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sonuç', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            if (result.warnings.isNotEmpty)
              Container(
                key: const ValueKey('warnings'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final w in result.warnings)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(w)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            for (final f in result.figures)
              _Row(
                label: f.label,
                value: formatQuantity(f.value, f.unit),
                emphasized: f.highlighted,
              ),
            if (price != null) ...[
              const Divider(height: 24),
              if (included)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Satır tutarları KDV dahil gösteriliyor.',
                    key: ValueKey('vat_included_note'),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              for (final line in price.lines)
                _Row(
                  label:
                      '${line.label} '
                      '(${formatQuantity(line.quantity, line.unit, maxDecimals: 3)}'
                      ' × ${price.displayAmount(line.unitPrice, display).format()})',
                  value: price.displayAmount(line.amount, display).format(),
                ),
              if (price.kinds.length > 1)
                for (final kind in price.kinds)
                  _Row(
                    key: ValueKey('kind_total_${kind.name}'),
                    label: '${kind.label} toplamı',
                    value: price
                        .displayAmount(price.totalOf(kind), display)
                        .format(),
                    secondary: true,
                  ),
              _Row(
                key: const ValueKey('subtotal'),
                label: 'Ara toplam (KDV hariç)',
                value: price.subtotal.format(),
              ),
              if (price.hasDiscount) ...[
                _Row(
                  key: const ValueKey('discount'),
                  label: 'İndirim (${price.discountRule!.description})',
                  value: '-${price.discount.format()}',
                ),
                _Row(
                  key: const ValueKey('tax_base'),
                  label: 'KDV matrahı',
                  value: price.taxBase.format(),
                ),
              ],
              _Row(
                key: const ValueKey('vat'),
                label: 'KDV (${formatPercent(price.vatPercent)})',
                value: price.vat.format(),
              ),
              const SizedBox(height: 4),
              _TotalRow(total: price.grandTotal),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tutar için birim fiyat veya ek maliyet girin.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('how_calculated'),
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: true,
                iconColor: AppColors.gold,
                collapsedIconColor: AppColors.textSecondary,
                title: const Text('Nasıl hesaplandı?'),
                children: [
                  for (final (i, step) in result.steps.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${i + 1}.',
                              style: const TextStyle(color: AppColors.gold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sonuç yokken gösterilen bilgi kartı.
class ResultPlaceholder extends StatelessWidget {
  const ResultPlaceholder({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('result_placeholder'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Ekranın altında sabit duran, her girişte güncellenen özet çubuğu.
/// Tek elle kullanımda sonuç için aşağı kaydırmak gerekmez.
class LiveTotalBar extends StatelessWidget {
  const LiveTotalBar({super.key, this.result, this.message});

  final CalculationResult? result;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    final String label;
    final String value;
    if (result == null) {
      label = message ?? 'Ölçüleri girin.';
      value = '';
    } else if (result.price case final price?) {
      label = 'Genel toplam';
      value = price.grandTotal.format();
    } else {
      final main = result.figures.firstWhere(
        (f) => f.highlighted,
        orElse: () => result.figures.first,
      );
      label = main.label;
      value = formatQuantity(main.value, main.unit);
    }

    return Container(
      key: const ValueKey('live_total'),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
              if (value.isNotEmpty)
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.secondary = false,
  });

  final String label;
  final String value;
  final bool emphasized;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final color = secondary ? AppColors.textSecondary : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: secondary ? color : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: emphasized ? AppColors.gold : color,
              fontSize: emphasized ? 18 : 15,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total});

  final Money total;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('grand_total'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Genel toplam (KDV dahil)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            total.format(),
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
