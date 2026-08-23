import 'package:flutter/widgets.dart';

import '../../../models/untracked_gap.dart';
import '../../../shared/widgets/dashed_border.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';
import 'claim_gap_sheet.dart';

/// An untracked interval: 3% black background with a dashed inner box
/// naming the gap. Tapping opens the claim sheet (screen 6).
class UntrackedGapWidget extends StatelessWidget {
  const UntrackedGapWidget({super.key, required this.gap});

  final UntrackedGap gap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showClaimGapSheet(context, gap),
      child: Container(
        color: AppColors.text.withValues(alpha: 0.03),
        padding: const EdgeInsets.all(AppSpacing.s1),
        child: DashedRectBorder(
          color: AppColors.ink(0.5),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s1),
            child: Text(
              '${formatDuration(gap.duration)} untracked',
              style: AppTextStyles.mono(),
            ),
          ),
        ),
      ),
    );
  }
}
