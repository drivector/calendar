import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/goal.dart';
import '../../../models/goal_planned_blocks.dart';
import '../../../models/goal_progress.dart';
import '../../../models/planned_block.dart';
import '../../../models/tracked_block.dart';
import '../../../shared/widgets/date_swipe_nav.dart';
import '../../../shared/widgets/step_arrow_button.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';
import 'goal_block.dart';
import 'goal_edit_sheet.dart';

/// A goal's detail view: its progress (reusing the same bar the list uses),
/// a chosen week's planned and actual activity broken out separately, and
/// an edit affordance. Not in the original handoff (its "Not yet designed"
/// section explicitly calls out goal detail) — built fresh in the app's own
/// system.
Future<void> showGoalDetailSheet(
  BuildContext context,
  WidgetRef ref,
  String goalId,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (context) => GoalDetailSheet(goalId: goalId, ref: ref),
  );
}

class GoalDetailSheet extends ConsumerStatefulWidget {
  const GoalDetailSheet({super.key, required this.goalId, required this.ref});

  final String goalId;
  // The WidgetRef the sheet was opened from — passed through to the edit
  // sheet so an edit made there can act on the same provider container.
  final WidgetRef ref;

  @override
  ConsumerState<GoalDetailSheet> createState() => _GoalDetailSheetState();
}

class _GoalDetailSheetState extends ConsumerState<GoalDetailSheet> {
  // The week being browsed — deliberately independent of the app's
  // globally selected date, so paging through a goal's history in here
  // doesn't also shift the Day/Week/Goals screens behind it. Starts on
  // whichever week the app is currently showing.
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = weekStartFor(widget.ref.read(selectedDateProvider));
  }

  void _stepWeek(int days) =>
      setState(() => _weekStart = _weekStart.add(Duration(days: days)));

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    Goal? goal;
    for (final g in goals) {
      if (g.id == widget.goalId) {
        goal = g;
        break;
      }
    }

    if (goal == null) {
      // The goal was deleted (e.g. from the edit sheet) while this was open.
      return const SizedBox.shrink();
    }

    final categories = ref.watch(categoriesProvider);
    final category = resolveCategory(categories, goal.categoryId);

    final weekEnd = _weekStart.add(const Duration(days: 7));
    bool inThisWeek(DateTime start) =>
        !start.isBefore(_weekStart) && start.isBefore(weekEnd);

    // Goal-generated (time-range) blocks for the browsed week — computed
    // locally rather than via goalGeneratedBlocksThisWeekProvider, which is
    // pinned to the app's globally selected week; this sheet needs to look
    // at whichever week it's currently browsing.
    final generatedThisWeek = <PlannedBlock>[
      for (var i = 0; i < 7; i++)
        ...generateGoalPlannedBlocksForDate(
          goals: goals,
          date: _weekStart.add(Duration(days: i)),
        ),
    ];

    // A manually planned/tracked block only carries a category, not a goal
    // id, so when another goal shares this one's category it's only
    // credited here if this goal is the one goalForCategory would resolve
    // that category to — otherwise the same hours would double-count
    // toward both goals (see _plannedHoursForGoal/_actualHoursForGoal in
    // state/goals_providers.dart for the same rule).
    final isPrimaryForCategory =
        goalForCategory(goals, goal.categoryId)?.id == goal.id;

    final plannedActivity = [
      if (isPrimaryForCategory)
        ...ref
            .watch(allPlannedBlocksProvider)
            .where(
              (b) => b.categoryId == goal!.categoryId && inThisWeek(b.start),
            ),
      ...generatedThisWeek.where((b) => b.goalId == goal!.id),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final actualActivity =
        (isPrimaryForCategory
            ? ref
                  .watch(allTrackedBlocksProvider)
                  .where(
                    (b) =>
                        b.categoryId == goal!.categoryId && inThisWeek(b.start),
                  )
                  .toList()
            : <TrackedBlock>[])
          ..sort((a, b) => a.start.compareTo(b.start));

    final plannedHours = plannedActivity.fold<double>(
      0,
      (t, b) => t + b.duration.inMinutes / 60,
    );
    final actualHours = actualActivity.fold<double>(
      0,
      (t, b) => t + b.duration.inMinutes / 60,
    );

    // Pace expectation ("expected by now") needs a reference point inside
    // the browsed week — the app's real "today" when browsing the current
    // week, clamped to the week's bounds otherwise (a fully-elapsed past
    // week reads as fully expected, a future week as nothing expected yet).
    final appToday = ref.read(selectedDateProvider);
    final paceReference = _clampToWeek(appToday, _weekStart, weekEnd);
    final progress = computeGoalProgress(
      goal: goal,
      actualHours: actualHours,
      plannedHours: plannedHours,
      date: paceReference,
    );

    final weekRangeLabel =
        '${DateFormat('d MMM').format(_weekStart)} – '
        '${DateFormat('d MMM').format(weekEnd.subtract(const Duration(days: 1)))}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
            borderRadius: AppShapes.sheetTop,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: DateSwipeNav(
            onPrevious: () => _stepWeek(-7),
            onNext: () => _stepWeek(7),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(goal.name, style: AppTextStyles.title()),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          showGoalEditSheet(
                            context,
                            widget.ref,
                            existing: goal,
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          'EDIT',
                          style: AppTextStyles.small(color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  _StatRow(
                    label: goal.isDateBound ? 'runs' : 'active',
                    value:
                        '${DateFormat('d MMM y').format(goal.startDate)} – '
                        '${DateFormat('d MMM y').format(goal.endDate)}',
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Week $weekRangeLabel', style: AppTextStyles.mono()),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StepArrowButton(
                            direction: StepDirection.previous,
                            onTap: () => _stepWeek(-7),
                          ),
                          const SizedBox(width: AppSpacing.s2),
                          StepArrowButton(
                            direction: StepDirection.next,
                            onTap: () => _stepWeek(7),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  GoalProgressBar(progress: progress, category: category.color),
                  const SizedBox(height: AppSpacing.s1),
                  Text(formatGoalStatus(progress), style: AppTextStyles.mono()),
                  const SizedBox(height: AppSpacing.s2),
                  _TargetPerDayRow(
                    key: const Key('goalDetailTargetPerDayRow'),
                    goal: goal,
                    weekStart: _weekStart,
                    actualActivity: actualActivity,
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  _StatRow(label: 'actual', value: formatHours(actualHours)),
                  _StatRow(
                    label: 'target',
                    // A byDate goal has no repeating weekly pattern to
                    // show here — its own total across every day it's
                    // actually been given entries for instead.
                    value: formatDuration(
                      goal.scheduleMode == GoalScheduleMode.byDate
                          ? goal.totalTarget
                          : goal.weeklyTarget,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.divider)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s3),
                      child: Text('PLANNED', style: AppTextStyles.kicker()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  if (plannedActivity.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s2,
                      ),
                      child: Text(
                        'Nothing planned this week.',
                        style: AppTextStyles.mono(),
                      ),
                    )
                  else
                    for (final block in plannedActivity)
                      _PlannedRow(block: block, color: category.color),
                  const SizedBox(height: AppSpacing.s2),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.divider)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s3),
                      child: Text('ACTUAL', style: AppTextStyles.kicker()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  if (actualActivity.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s2,
                      ),
                      child: Text(
                        'No activity this week.',
                        style: AppTextStyles.mono(),
                      ),
                    )
                  else
                    for (final block in actualActivity)
                      _ActualRow(block: block, color: category.color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clamps [date] into `[weekStart, weekEnd)` — used to turn the app's real
/// "today" into a sensible pace reference for whichever week is being
/// browsed: unchanged for the current week, pinned to the end for a fully
/// past week (100% expected), pinned to the start for a future one (0%).
DateTime _clampToWeek(DateTime date, DateTime weekStart, DateTime weekEnd) {
  if (date.isBefore(weekStart)) return weekStart;
  if (!date.isBefore(weekEnd)) {
    return weekEnd.subtract(const Duration(minutes: 1));
  }
  return date;
}

/// A compact 7-day strip of each weekday's own target, with that day's
/// actual tracked time right below it — the "target"/"actual" stat rows
/// above only ever show weekly totals, which hides exactly how a goal like
/// "Walking / varies by day" actually varies, and which specific days it's
/// on or off pace; this spells out every day at a glance.
class _TargetPerDayRow extends StatelessWidget {
  const _TargetPerDayRow({
    super.key,
    required this.goal,
    required this.weekStart,
    required this.actualActivity,
  });

  final Goal goal;
  final DateTime weekStart;
  final List<TrackedBlock> actualActivity;

  Duration _actualForDay(DateTime day) => actualActivity
      .where((b) => isSameDay(b.start, day))
      .fold(Duration.zero, (total, b) => total + b.duration);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var offset = 0; offset < 7; offset++)
          _dayColumn(weekStart.add(Duration(days: offset))),
      ],
    );
  }

  Widget _dayColumn(DateTime day) {
    // targetForDate resolves correctly for either schedule mode (the
    // weekday's own repeating target, or this exact date's own entries)
    // — see Goal.entriesForOccurrence's own doc comment.
    final target = goal.targetForDate(day);
    final actual = _actualForDay(day);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('EEE').format(day).toUpperCase(),
              style: AppTextStyles.mono(),
            ),
            Text(
              target == Duration.zero ? 'off' : formatDuration(target),
              style: AppTextStyles.mono(color: AppColors.text),
            ),
            Text(
              actual == Duration.zero ? '—' : formatDuration(actual),
              style: AppTextStyles.mono(color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.mono()),
          Text(value, style: AppTextStyles.mono(color: AppColors.text)),
        ],
      ),
    );
  }
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// Includes the date, not just the weekday name — once a goal's detail
// sheet can browse any week (not just the current one), "MON" alone is
// ambiguous about which Monday.
String _dayLabel(DateTime t) => DateFormat('EEE d').format(t).toUpperCase();

class _PlannedRow extends StatelessWidget {
  const _PlannedRow({required this.block, required this.color});

  final PlannedBlock block;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashedTick(color: color),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(block.title, style: AppTextStyles.label()),
                  Text(
                    '${_dayLabel(block.start)} ${_clock(block.start)}–${_clock(block.end)}',
                    style: AppTextStyles.mono(),
                  ),
                ],
              ),
            ),
            Text(
              formatDuration(block.duration),
              style: AppTextStyles.mono(color: AppColors.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedTick extends StatelessWidget {
  const _DashedTick({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 8; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Container(width: 3, height: 2, color: color),
          ),
      ],
    );
  }
}

class _ActualRow extends StatelessWidget {
  const _ActualRow({required this.block, required this.color});

  final TrackedBlock block;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 3, height: 32, color: color),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(block.title, style: AppTextStyles.label()),
                  Text(
                    '${_dayLabel(block.start)} ${_clock(block.start)}–${_clock(block.end)} '
                    '· ${block.sourceId}',
                    style: AppTextStyles.mono(),
                  ),
                ],
              ),
            ),
            Text(
              formatDuration(block.duration),
              style: AppTextStyles.mono(color: AppColors.text),
            ),
          ],
        ),
      ),
    );
  }
}
