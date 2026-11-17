import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../engine/calculation_result.dart';
import '../../../engine/money.dart';
import '../../../engine/number_format.dart';
import '../../../engine/pricing.dart';

/// Hesap sonucunu, fiyat özetini ve "Nasıl hesaplandı?" adımlarını gösterir.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.result});

  final CalculationResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = result.price;

    return Card(
      key: const ValueKey('result_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sonuç', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final f in result.figures)
              _Row(
                label: f.label,
                value: formatQuantity(f.value, f.unit),
                emphasized: f.highlighted,
              ),
            if (price != null) ...[
              const Divider(height: 24),
              for (final line in price.lines)
                _Row(
                  label:
                      '${line.label} '
                      '(${formatQuantity(line.quantity, line.unit, maxDecimals: 3)}'
                      ' × ${line.unitPrice.format()})',
                  value: line.amount.format(),
                ),
              if (_hasMaterialAndLabor(price)) ...[
                _Row(
                  label: 'Malzeme toplamı',
                  value: price.totalOf(CostKind.material).format(),
                  secondary: true,
                ),
                _Row(
                  label: 'İşçilik toplamı',
                  value: price.totalOf(CostKind.labor).format(),
                  secondary: true,
                ),
              ],
              _Row(
                key: const ValueKey('subtotal'),
                label: 'Ara toplam',
                value: price.subtotal.format(),
              ),
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
                  'Tutar için birim fiyat girin.',
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
                            width: 24,
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

  static bool _hasMaterialAndLabor(PriceSummary p) =>
      p.lines.any((l) => l.kind == CostKind.material) &&
      p.lines.any((l) => l.kind == CostKind.labor);
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
              'Genel toplam',
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
