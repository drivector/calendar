import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/dashed_border.dart';
import '../../../state/derived_providers.dart';
import '../../../theme/app_category_colors.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';

/// Two items: a dashed swatch for "planned", a tinted+edged swatch for
/// "tracked" — totals computed as real sums over the day's data.
class LegendRow extends ConsumerWidget {
  const LegendRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (plannedTotal, trackedTotal) = ref.watch(dayTotalsProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        child: Row(
          children: [
            _LegendItem(
              swatch: DashedRectBorder(
                color: AppColors.ink(0.5),
                child: const SizedBox(width: 14, height: 10),
              ),
              label: 'planned ${formatDuration(plannedTotal)}',
            ),
            const SizedBox(width: AppSpacing.s4),
            _LegendItem(
              swatch: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppCategoryColors.blockFill(AppColors.accent),
                  border: Border(
                    left: BorderSide(color: AppColors.accent, width: 3),
                  ),
                ),
                child: const SizedBox(width: 14, height: 10),
              ),
              label: 'tracked ${formatDuration(trackedTotal)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.swatch, required this.label});

  final Widget swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.mono()),
      ],
    );
  }
}
