import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:flutter/widgets.dart';

import '../../../models/category.dart';
import '../../../models/tracked_block.dart';
import '../../../theme/app_category_colors.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// A tracked block: 15%-tint fill, 3px solid left border in the category
/// color, title plus a monospace source line. Tapping opens a detail sheet.
class ActualBlockWidget extends StatelessWidget {
  const ActualBlockWidget({
    super.key,
    required this.block,
    required this.category,
  });

  final TrackedBlock block;
  final Category category;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showDetailSheet(context, block, category.name),
      child: Container(
        alignment: Alignment.topLeft,
        decoration: BoxDecoration(
          color: AppCategoryColors.blockFill(category.color),
          border: Border(left: BorderSide(color: category.color, width: 3)),
        ),
        padding: const EdgeInsets.all(AppSpacing.s1),
        // maxLines/ellipsis on both lines — a narrow multi-day column
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
            Text(
              '(${block.sourceId})',
              style: AppTextStyles.mono(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

void _showDetailSheet(
  BuildContext context,
  TrackedBlock block,
  String categoryName,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(block.title, style: AppTextStyles.title()),
            const SizedBox(height: AppSpacing.s2),
            Text('Source: ${block.sourceId}', style: AppTextStyles.mono()),
            Text('Category: $categoryName', style: AppTextStyles.mono()),
            Text(
              'Counts toward: $categoryName goal',
              style: AppTextStyles.mono(),
            ),
          ],
        ),
      );
    },
  );
}
