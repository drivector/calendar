import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/goal_progress.dart';
import '../../../models/planned_block.dart';
import '../../../models/tracked_block.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';
import 'goal_block.dart';
import 'goal_edit_sheet.dart';

/// A goal's detail view: its progress (reusing the same bar the list uses),
/// this week's planned and actual activity broken out separately, and an
/// edit affordance. Not in the original handoff (its "Not yet designed"
/// section explicitly calls out goal detail) — built fresh in the app's own
/// system.
Future<void> showGoalDetailSheet(
  BuildContext context,
  WidgetRef ref,
  String goalId,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    isScrollControlled: true,
    builder: (context) => GoalDetailSheet(goalId: goalId, ref: ref),
  );
}

class GoalDetailSheet extends ConsumerWidget {
  const GoalDetailSheet({super.key, required this.goalId, required this.ref});

  final String goalId;
  // The WidgetRef the sheet was opened from — passed through to the edit
  // sheet so an edit made there can act on the same provider container.
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef watchRef) {
    final progressList = watchRef.watch(goalProgressListProvider);
    GoalProgress? progress;
    for (final p in progressList) {
      if (p.goal.id == goalId) {
        progress = p;
        break;
      }
    }

    if (progress == null) {
      // The goal was deleted (e.g. from the edit sheet) while this was open.
      return const SizedBox.shrink();
    }

    final selectedDate = watchRef.watch(selectedDateProvider);
    final categories = watchRef.watch(categoriesProvider);
    final category = resolveCategory(categories, progress.goal.categoryId);

    final weekStart = weekStartFor(selectedDate);
    final weekEnd = weekStart.add(const Duration(days: 7));
    bool inThisWeek(DateTime start) =>
        !start.isBefore(weekStart) && start.isBefore(weekEnd);

    final generatedThisWeek = watchRef.watch(goalGeneratedBlocksThisWeekProvider);
    final plannedActivity = [
      ...watchRef
          .watch(allPlannedBlocksProvider)
          .where((b) => b.categoryId == progress!.goal.categoryId && inThisWeek(b.start)),
      ...generatedThisWeek.where((b) => b.goalId == progress!.goal.id),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final actualActivity = watchRef
        .watch(allTrackedBlocksProvider)
        .where((b) => b.categoryId == progress!.goal.categoryId && inThisWeek(b.start))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.text, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(progress.goal.name, style: AppTextStyles.title()),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        showGoalEditSheet(context, ref, existing: progress!.goal);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Text('EDIT', style: AppTextStyles.small(color: AppColors.accent)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                GoalProgressBar(progress: progress, category: category.color),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  formatGoalStatus(progress),
                  style: AppTextStyles.mono(
                    color: progress.status == GoalStatus.overCap
                        ? AppColors.accent700
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                _StatRow(
                  label: 'planned',
                  value: '${progress.plannedHours.toStringAsFixed(1)} h',
                ),
                _StatRow(
                  label: 'actual',
                  value: '${progress.actualHours.toStringAsFixed(1)} h',
                ),
                _StatRow(
                  label: 'target',
                  value: '${formatDuration(progress.goal.weeklyTarget)} this week '
                      '· today ${formatDuration(progress.goal.targetForWeekday(selectedDate.weekday))}',
                ),
                if (progress.goal.isDateBound)
                  _StatRow(
                    label: 'runs',
                    value: '${DateFormat('d MMM y').format(progress.goal.startDate)} – '
                        '${DateFormat('d MMM y').format(progress.goal.endDate)}',
                  ),
                const SizedBox(height: AppSpacing.s2),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s3),
                    child: Text('PLANNED THIS WEEK', style: AppTextStyles.kicker()),
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                if (plannedActivity.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                    child: Text('Nothing planned yet.', style: AppTextStyles.mono()),
                  )
                else
                  for (final block in plannedActivity)
                    _PlannedRow(
                      block: block,
                      color: category.color,
                      // A generated block from a duration-mode goal has no
                      // fixed clock time of its own — the placement shown
                      // here is just wherever it happened to land that day,
                      // recomputed on the fly, not something stored on the
                      // goal. Flag it so it doesn't read as an editable
                      // commitment the way a time-range goal's block is.
                      isAutoPlaced: block.isGoalAutoPlaced,
                    ),
                const SizedBox(height: AppSpacing.s2),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s3),
                    child: Text('ACTUAL THIS WEEK', style: AppTextStyles.kicker()),
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                if (actualActivity.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                    child: Text('No activity yet.', style: AppTextStyles.mono()),
                  )
                else
                  for (final block in actualActivity)
                    _ActualRow(block: block, color: category.color),
              ],
            ),
          ),
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

String _dayLabel(DateTime t) => DateFormat('EEE').format(t).toUpperCase();

class _PlannedRow extends StatelessWidget {
  const _PlannedRow({
    required this.block,
    required this.color,
    required this.isAutoPlaced,
  });

  final PlannedBlock block;
  final Color color;
  final bool isAutoPlaced;

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
                    '${_dayLabel(block.start)} ${_clock(block.start)}–${_clock(block.end)}'
                    '${isAutoPlaced ? ' · auto-placed' : ''}',
                    style: AppTextStyles.mono(),
                  ),
                ],
              ),
            ),
            Text(formatDuration(block.duration), style: AppTextStyles.mono(color: AppColors.text)),
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
            Text(formatDuration(block.duration), style: AppTextStyles.mono(color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}
