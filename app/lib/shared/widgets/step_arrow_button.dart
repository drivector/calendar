import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum StepDirection { previous, next }

/// A flat, bordered "‹"/"›" button — same visual language as the goal
/// sheet's +/- steppers, reused here for day/week navigation.
class StepArrowButton extends StatelessWidget {
  const StepArrowButton({super.key, required this.direction, required this.onTap});

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
        decoration: BoxDecoration(border: Border.all(color: AppColors.text)),
        child: Text(
          direction == StepDirection.previous ? '<' : '>',
          style: AppTextStyles.label(),
        ),
      ),
    );
  }
}
