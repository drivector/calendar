import 'package:flutter/widgets.dart';

import '../../../models/category.dart';
import '../../../models/planned_block.dart';
import '../../../shared/widgets/dashed_border.dart';
import '../../../theme/app_category_colors.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// A planned block: a rounded 1px dashed outline in its category color,
/// lightly filled with that same color at 30% so it still reads clearly
/// under a solid actual block for the same slot rather than competing
/// with it. When [onConfirm] is set (nothing was tracked against this
/// plan), an inline "Confirm" affordance accepts the plan as actual.
class PlanBlockWidget extends StatelessWidget {
  const PlanBlockWidget({
    super.key,
    required this.block,
    required this.category,
    this.onConfirm,
  });

  final PlannedBlock block;
  final Category category;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return DashedRectBorder(
      color: category.color,
      child: Container(
        alignment: Alignment.topLeft,
        decoration: BoxDecoration(
          color: AppCategoryColors.planFill(category.color),
          borderRadius: AppShapes.small,
        ),
        padding: const EdgeInsets.all(AppSpacing.s1),
        // maxLines/ellipsis on the title — a narrow multi-day column
        // (Working week/Week mode) is narrow enough that unbounded text
        // would wrap onto more lines than the block's minimum height fits,
        // overflowing it.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              block.title,
              style: AppTextStyles.label(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
