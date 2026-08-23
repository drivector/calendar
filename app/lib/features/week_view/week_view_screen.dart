import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/goal_progress.dart';
import '../../shared/widgets/date_swipe_nav.dart';
import '../../shared/widgets/segmented_control.dart';
import '../../shared/widgets/step_arrow_button.dart';
import '../../state/day_view_providers.dart';
import '../../state/goals_providers.dart';
import '../../state/root_shell_providers.dart';
import '../../state/week_view_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/duration_format.dart';
import 'widgets/week_day_row.dart';

enum _DayWeekTab { day, week }

Duration _hoursToDuration(double hours) => Duration(minutes: (hours * 60).round());

/// Screen 3 — "Week view (mobile)" (option #4b).
class WeekViewScreen extends ConsumerWidget {
  const WeekViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(weekDaySummariesProvider);
    final (plannedHours, trackedHours) = ref.watch(weekTotalsProvider);
    final goalProgressList = ref.watch(goalProgressListProvider);

    final rangeLabel =
        '${DateFormat('d').format(days.first.date)} – '
        '${DateFormat('d MMM').format(days.last.date)}';

    void step(int deltaDays) {
      final current = ref.read(selectedDateProvider);
      ref.read(selectedDateProvider.notifier).state =
          current.add(Duration(days: deltaDays));
    }

    return DateSwipeNav(
      onPrevious: () => step(-7),
      onNext: () => step(7),
      child: ColoredBox(
      color: AppColors.bg,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.text, width: 2)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StepArrowButton(
                        direction: StepDirection.previous,
                        onTap: () => step(-7),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Text('Week $rangeLabel', style: AppTextStyles.title()),
                      const SizedBox(width: AppSpacing.s2),
                      StepArrowButton(
                        direction: StepDirection.next,
                        onTap: () => step(7),
                      ),
                    ],
                  ),
                  SegmentedControl<_DayWeekTab>(
                    selected: _DayWeekTab.week,
                    onChanged: (value) {
                      if (value == _DayWeekTab.day) {
                        ref.read(currentTabIndexProvider.notifier).state = 0;
                      }
                    },
                    options: const [
                      SegmentedOption(value: _DayWeekTab.day, label: 'Day'),
                      SegmentedOption(value: _DayWeekTab.week, label: 'Week'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Tracked', style: AppTextStyles.kicker()),
                      Text(
                        formatDuration(_hoursToDuration(trackedHours)),
                        style: AppTextStyles.title().copyWith(fontSize: 24),
                      ),
                    ],
                  ),
                  Text(
                    'planned ${formatDuration(_hoursToDuration(plannedHours))} · '
                    '${formatSignedDuration(_hoursToDuration(trackedHours - plannedHours))}',
                    style: AppTextStyles.mono(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final day in days) WeekDayRow(summary: day),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.text, width: 2)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Against goals', style: AppTextStyles.kicker()),
                  const SizedBox(height: AppSpacing.s1),
                  for (final progress in goalProgressList)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            progress.goal.name.toLowerCase(),
                            style: AppTextStyles.mono(color: AppColors.text),
                          ),
                          Text(
                            '${progress.actualHours.toStringAsFixed(1)} / '
                            '${progress.goal.weeklyTargetHours.toStringAsFixed(0)} h'
                            '${progress.status == GoalStatus.overCap ? ' — over' : ''}',
                            style: AppTextStyles.mono(color: AppColors.text),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
