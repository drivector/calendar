import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/goal_progress.dart';
import '../../../state/categories_providers.dart';
import '../../../theme/app_category_colors.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';

class GoalBlock extends ConsumerWidget {
  const GoalBlock({super.key, required this.progress});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final category = resolveCategory(categories, progress.goal.categoryId);
    final goal = progress.goal;
    final targetLabel =
        '${formatHours(progress.actualHours)} / ${formatDuration(goal.weeklyTarget)}';
    final perDayCaption = goal.isUniformAcrossWeek
        ? '/ ${formatDuration(goal.targetForWeekday(DateTime.monday))} per day'
        : '/ varies by day';

    // A white Fluent card lifted off the canvas, with the category colour
    // as a bar down its leading edge — the same anatomy as an Outlook
    // calendar chip, at list scale.
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s3,
        AppSpacing.s2,
        AppSpacing.s3,
        AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: category.color, width: 3)),
        borderRadius: AppShapes.medium,
        boxShadow: AppShapes.shadow2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(progress.goal.name, style: AppTextStyles.title()),
                  const SizedBox(width: AppSpacing.s1),
                  Text(perDayCaption, style: AppTextStyles.mono()),
                ],
              ),
              Text(
                targetLabel,
                style: AppTextStyles.mono(color: AppColors.text),
              ),
            ],
          ),
          if (goal.isDateBound)
            Text(
              '${DateFormat('d MMM').format(goal.startDate)} – '
              '${DateFormat('d MMM').format(goal.endDate)}',
              style: AppTextStyles.mono(),
            ),
          const SizedBox(height: AppSpacing.s2),
          GoalProgressBar(progress: progress, category: category.color),
          const SizedBox(height: AppSpacing.s1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatGoalStatus(progress), style: AppTextStyles.mono()),
              if (progress.plannedHours > 0)
                Text(
                  'planned ${formatHours(progress.plannedHours)}',
                  style: AppTextStyles.mono(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Next to each goal in the list — turns this week's remaining planned
/// blocks into real tracked activity in one tap (see
/// `models/goal_completion.dart`). Same bordered/accent-glyph language as
/// [StepArrowButton], so it reads as part of the same control family
/// rather than a one-off.
class CompleteGoalButton extends StatelessWidget {
  const CompleteGoalButton({super.key, required this.onTap});

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
          border: Border.all(color: AppColors.neutral500), borderRadius: AppShapes.small,
        ),
        child: Text(
          '✓',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}

class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({
    super.key,
    required this.progress,
    required this.category,
  });

  final GoalProgress progress;
  final Color category;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Only the track and fill are clipped to the rounded pill —
          // Fluent progress bars are slim and fully rounded, not the
          // chunky square meter the flat system used. The pace marker
          // below deliberately overhangs the bar, so it stays outside
          // this clip or it would be cut off.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppCategoryColors.blockFill(category),
                    ),
                  ),
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.completionFraction,
                      child: ColoredBox(color: category),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: -3,
            bottom: -3,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.expectedByNowFraction,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(width: 2, color: AppColors.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
