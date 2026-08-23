import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/goal_progress.dart';
import '../../../state/categories_providers.dart';
import '../../../theme/app_category_colors.dart';
import '../../../theme/app_colors.dart';
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
        '${progress.actualHours.toStringAsFixed(1)} h / ${formatDuration(goal.weeklyTarget)}';
    final perDayCaption = goal.isUniformAcrossWeek
        ? '/ ${formatDuration(goal.targetForWeekday(DateTime.monday))} per day'
        : '/ varies by day';

    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.s3),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: category.color, width: 3)),
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
              Text(targetLabel, style: AppTextStyles.mono(color: AppColors.text)),
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
              Text(
                formatGoalStatus(progress),
                style: AppTextStyles.mono(
                  color: progress.status == GoalStatus.overCap
                      ? AppColors.accent700
                      : null,
                ),
              ),
              if (progress.plannedHours > 0)
                Text(
                  'planned ${progress.plannedHours.toStringAsFixed(1)} h',
                  style: AppTextStyles.mono(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({super.key, required this.progress, required this.category});

  final GoalProgress progress;
  final Color category;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: AppCategoryColors.blockFill(category)),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.completionFraction,
              child: ColoredBox(color: category),
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
