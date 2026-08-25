import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// A pill-shaped category filter, Outlook-style. Unselected: hairline
/// border with a small round category swatch. Selected: solid category
/// fill, white label and swatch.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.surface : AppColors.text;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2,
          vertical: AppSpacing.s1,
        ),
        decoration: BoxDecoration(
          color: selected ? color : null,
          border: Border.all(
            color: selected ? color : AppColors.neutral500,
          ),
          borderRadius: AppShapes.medium,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: selected ? AppColors.surface : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.s1),
            Text(label, style: AppTextStyles.mono(color: foreground)),
          ],
        ),
      ),
    );
  }
}
