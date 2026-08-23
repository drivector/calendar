import 'package:flutter/widgets.dart';

import '../../../models/planned_block.dart';
import '../../../shared/widgets/dashed_border.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// A planned block: 1px dashed 50%-ink outline, 4px padding, its label.
/// When [onConfirm] is set (nothing was tracked against this plan), an
/// inline "Confirm" affordance accepts the plan as actual.
class PlanBlockWidget extends StatelessWidget {
  const PlanBlockWidget({super.key, required this.block, this.onConfirm});

  final PlannedBlock block;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return DashedRectBorder(
      color: AppColors.ink(0.5),
      child: Container(
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.all(AppSpacing.s1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(block.title, style: AppTextStyles.label()),
            if (onConfirm != null)
              GestureDetector(
                onTap: onConfirm,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s1),
                  child: Text(
                    'Confirm',
                    style: AppTextStyles.small(color: AppColors.accent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
