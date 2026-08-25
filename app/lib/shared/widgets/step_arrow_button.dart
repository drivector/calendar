import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_shapes.dart';

enum StepDirection { previous, next }

/// A subtle "‹"/"›" navigation button — same visual language as the goal
/// sheet's +/- steppers, reused here for day/week navigation. Outlook keeps
/// these quiet: a hairline-bordered white square with a neutral chevron,
/// rather than a filled or accented control.
class StepArrowButton extends StatelessWidget {
  const StepArrowButton({
    super.key,
    required this.direction,
    required this.onTap,
  });

  final StepDirection direction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.neutral500),
          borderRadius: AppShapes.small,
        ),
        child: Text(
          direction == StepDirection.previous ? '‹' : '›',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
