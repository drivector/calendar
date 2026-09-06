import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_shapes.dart';

/// A small bordered checkmark button — "mark as done" in one tap. Green
/// rather than [AppColors.accent]'s blue: this specifically means a
/// completion action, not an ordinary primary action, and needs to read
/// as distinct from whatever "close"/"edit"/link text sits near it in the
/// same row. Same bordered/glyph language as `CompleteGoalButton` (the
/// Goals list's own one-tap completion action), just a shared, reusable
/// version — used by the unscheduled dialog's own quick-log row (see
/// `logUnscheduledGoalTime`) in both the Day view legend and the
/// Capacity page's day preview.
class QuickLogCheckButton extends StatelessWidget {
  const QuickLogCheckButton({super.key, required this.onTap});

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
          border: Border.all(color: AppColors.neutral500),
          borderRadius: AppShapes.small,
        ),
        child: Text(
          '✓',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1,
            color: AppColors.success,
          ),
        ),
      ),
    );
  }
}
