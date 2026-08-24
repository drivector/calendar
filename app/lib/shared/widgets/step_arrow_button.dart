import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';

enum StepDirection { previous, next }

/// A flat, bordered "‹"/"›" button — same visual language as the goal
/// sheet's +/- steppers, reused here for day/week navigation. The chevron
/// is accent-colored (the border stays neutral) to tie the control to the
/// app's one accent color without needing a filled/colored background,
/// which the flat design system doesn't otherwise use for buttons.
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
          border: Border.all(color: AppColors.text, width: 1.5),
        ),
        child: Text(
          direction == StepDirection.previous ? '‹' : '›',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}
