import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/day_view_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

const kGutterWidth = 38.0;

class ColumnHeaders extends ConsumerWidget {
  const ColumnHeaders({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayLayer = ref.watch(dayLayerProvider);
    final showPlan = dayLayer == DayLayer.planAndActual;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.text, width: 2)),
      ),
      child: Row(
        children: [
          const SizedBox(width: kGutterWidth),
          if (showPlan) const Expanded(child: _ColumnHeaderCell('Plan')),
          const Expanded(child: _ColumnHeaderCell('Actual')),
        ],
      ),
    );
  }
}

class _ColumnHeaderCell extends StatelessWidget {
  const _ColumnHeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2,
          vertical: AppSpacing.s1,
        ),
        child: Text(label.toUpperCase(), style: AppTextStyles.kicker()),
      ),
    );
  }
}
