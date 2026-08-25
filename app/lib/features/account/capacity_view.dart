import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/day_capacity.dart';
import '../../models/goal_progress.dart';
import '../../shared/widgets/hatch_pattern.dart';
import '../../state/categories_providers.dart';
import '../../state/goals_providers.dart';
import '../../state/week_view_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/duration_format.dart';

/// "How much is planned, and how much is still available" — shows plan vs.
/// available time per day and per goal for the current week. Two sections:
/// free time slots per day (against the same 07:00–18:00 window the Day
/// view already uses for "untracked"), and remaining room per goal (target
/// minus what's already planned toward it this week).
///
/// A body, not a screen: it's one of the Account screen's segments, so the
/// surrounding chrome (background, safe area, header) belongs to
/// [AccountScreen] rather than being repeated here.
class CapacityView extends ConsumerWidget {
  const CapacityView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(weekDayCapacityProvider);
    final goalProgressList = ref.watch(goalProgressListProvider);
    final categories = ref.watch(categoriesProvider);

    final totalPlanned = days.fold<double>(0, (t, d) => t + d.plannedHours);
    final totalAvailable = days.fold<double>(0, (t, d) => t + d.availableHours);
    final totalWindow = days.fold<double>(0, (t, d) => t + d.windowHours);

    return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Planned', style: AppTextStyles.kicker()),
                        Text('Available', style: AppTextStyles.kicker()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatHours(totalPlanned),
                          style: AppTextStyles.title().copyWith(fontSize: 24),
                        ),
                        Text(
                          '${formatHours(totalAvailable)} of '
                          '${formatHours(totalWindow)} this week',
                          style: AppTextStyles.mono(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text('FREE TIME PER DAY', style: AppTextStyles.kicker()),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'against each day\'s 07:00–18:00 window — the same one '
                      'the Day view uses for "untracked"',
                      style: AppTextStyles.mono(),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    for (final day in days) _DayCapacityRow(day: day),
                    const SizedBox(height: AppSpacing.s4),
                    Text('ROOM TOWARD GOALS', style: AppTextStyles.kicker()),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'each goal\'s weekly target minus what\'s already planned',
                      style: AppTextStyles.mono(),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    if (goalProgressList.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s2,
                        ),
                        child: Text(
                          'No active goals this week.',
                          style: AppTextStyles.mono(),
                        ),
                      )
                    else
                      for (final progress in goalProgressList)
                        _GoalRoomRow(
                          progress: progress,
                          color: resolveCategory(
                            categories,
                            progress.goal.categoryId,
                          ).color,
                        ),
                  ],
                ),
              );
  }
}

class _DayCapacityRow extends StatelessWidget {
  const _DayCapacityRow({required this.day});

  final DayCapacity day;

  @override
  Widget build(BuildContext context) {
    final plannedFlex = (day.plannedHours * 100).round().clamp(0, 1 << 30);
    final availableFlex = (day.availableHours * 100).round().clamp(0, 1 << 30);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              DateFormat('EEE d').format(day.date).toUpperCase(),
              style: AppTextStyles.mono(),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 14,
              child: plannedFlex == 0 && availableFlex == 0
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        if (plannedFlex > 0)
                          Expanded(
                            flex: plannedFlex,
                            child: ColoredBox(color: AppColors.text),
                          ),
                        if (plannedFlex > 0 && availableFlex > 0)
                          const SizedBox(width: 2),
                        if (availableFlex > 0)
                          Expanded(
                            flex: availableFlex,
                            child: const HatchPatternBox(),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          SizedBox(
            width: 96,
            child: Text(
              day.overplannedHours > 0
                  ? 'over by ${formatHours(day.overplannedHours)}'
                  : '${formatHours(day.availableHours)} free',
              textAlign: TextAlign.right,
              style: AppTextStyles.mono(
                color: day.overplannedHours > 0 ? AppColors.accent : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalRoomRow extends StatelessWidget {
  const _GoalRoomRow({required this.progress, required this.color});

  final GoalProgress progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final target = progress.goal.weeklyTargetHours;
    final available = (target - progress.plannedHours).clamp(
      0.0,
      target == 0 ? 0.0 : double.infinity,
    );
    final over = progress.plannedHours > target
        ? progress.plannedHours - target
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
      child: Row(
        children: [
          Container(width: 8, height: 8, color: color),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              '${progress.goal.name} · planned ${formatHours(progress.plannedHours)} '
              '/ ${formatHours(target)}',
              style: AppTextStyles.label(),
            ),
          ),
          Text(
            over > 0
                ? 'over by ${formatHours(over)}'
                : '${formatHours(available)} room',
            style: AppTextStyles.mono(
              color: over > 0 ? AppColors.accent : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
