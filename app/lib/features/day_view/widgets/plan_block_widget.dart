import 'package:flutter/widgets.dart';

import '../../../models/category.dart';
import '../../../models/planned_block.dart';
import '../../../shared/widgets/dashed_border.dart';
import '../../../theme/app_category_colors.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';
import 'block_label_style.dart';

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
    required this.labelStyle,
    this.onConfirm,
  });

  final PlannedBlock block;
  final Category category;
  final VoidCallback? onConfirm;

  // How much text this block's own real, unclamped height has room for —
  // see [BlockLabelStyle]'s own doc comment. A plan's box always renders
  // at its real start/end time, with no minimum floor, so a short plan
  // needs a content layout that fits its own real (shorter) height
  // instead of always assuming room for two lines.
  final BlockLabelStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final showConfirm = onConfirm != null && labelStyle == BlockLabelStyle.full;
    Widget? label;
    switch (labelStyle) {
      case BlockLabelStyle.full:
        label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              block.title,
              style: AppTextStyles.label(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              formatDuration(block.duration),
              style: AppTextStyles.mono(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Compact/hidden plans skip this — there's no room for a third
            // line once already at the two-line minimum, and a sub-two-line
            // plan is short enough that "Confirm" isn't worth losing the
            // duration label over.
            if (showConfirm)
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
        );
      case BlockLabelStyle.compact:
        label = Text(
          '${formatDuration(block.duration)} · ${block.title}',
          style: AppTextStyles.mono(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case BlockLabelStyle.hidden:
        // Too short for even one line — a plain dashed outline, no text,
        // rather than clipped, illegible characters.
        label = null;
    }
    return DashedRectBorder(
      color: category.color,
      child: Container(
        alignment: labelStyle == BlockLabelStyle.full
            ? Alignment.topLeft
            : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppCategoryColors.planFill(category.color),
          borderRadius: AppShapes.small,
        ),
        padding: label == null
            ? EdgeInsets.zero
            : const EdgeInsets.all(AppSpacing.s1),
        // maxLines/ellipsis throughout — a narrow multi-day column
        // (Working week/Week mode) is narrow enough that unbounded text
        // would wrap onto more lines than the block's own height fits,
        // overflowing it.
        child: label,
      ),
    );
  }
}
