import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';

enum StepDirection { previous, next }

/// A bare "‹"/"›" navigation chevron for day/week stepping. No box: Outlook
/// leaves its calendar's back/forward controls as plain glyphs, and boxing
/// them competes with the one filled button the header is allowed.
///
/// The 32×32 footprint stays even without a visible border — it's the tap
/// target, and this repo's conventions require a real one.
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
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Text(
            direction == StepDirection.previous ? '‹' : '›',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 1,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
