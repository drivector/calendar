import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/goal_completion.dart';
import '../../models/goal_progress.dart';
import '../../models/planned_block.dart';
import '../../shared/widgets/date_swipe_nav.dart';
import '../../state/day_view_providers.dart';
import '../../state/goals_providers.dart';
import '../../state/root_shell_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../categories/categories_screen.dart';
import 'widgets/goal_block.dart';
import 'widgets/goal_detail_sheet.dart';
import 'widgets/goal_edit_sheet.dart';

/// Screen 4 — "Goals" (option #2b). Each goal carries its own per-weekday
/// targets, so there's no single Week/Month toggle for the whole list.
/// Tapping a goal opens its detail (progress + activity); "+ New goal" and
/// the detail sheet's "Edit" both open the same create/edit sheet.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressList = ref.watch(goalProgressListProvider);
    final weekStart = weekStartFor(ref.watch(selectedDateProvider));
    final allPlanned = ref.watch(allPlannedBlocksProvider);
    final generatedThisWeek = ref.watch(goalGeneratedBlocksThisWeekProvider);
    final allTracked = ref.watch(allTrackedBlocksProvider);

    void stepTab(int delta) {
      final next = (ref.read(currentTabIndexProvider) + delta).clamp(0, 3);
      ref.read(currentTabIndexProvider.notifier).state = next;
    }

    return DateSwipeNav(
      onPrevious: () => stepTab(-1),
      onNext: () => stepTab(1),
      child: ColoredBox(
        color: AppColors.bg,
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.text, width: 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Goals', style: AppTextStyles.title()),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoriesScreen(),
                        ),
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Text('categories', style: AppTextStyles.mono()),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final progress in progressList) ...[
                      _GoalRow(
                        progress: progress,
                        pending: pendingPlannedBlocksForGoal(
                          goal: progress.goal,
                          allPlanned: allPlanned,
                          generatedThisWeek: generatedThisWeek,
                          allTracked: allTracked,
                          weekStart: weekStart,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                    ],
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.divider),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s3),
                        child: GestureDetector(
                          onTap: () => showGoalEditSheet(context, ref),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.text,
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s3,
                            ),
                            child: Text(
                              '+ NEW GOAL',
                              style: AppTextStyles.small(color: AppColors.text),
                            ),
                          ),
                        ),
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

/// One goal row: the whole block is tappable to open its detail, plus a
/// "complete" button — shown only when there's actually something pending
/// (see [pendingPlannedBlocksForGoal]) — that turns this week's remaining
/// planned blocks into real tracked activity in one tap, without opening
/// the detail sheet.
class _GoalRow extends ConsumerWidget {
  const _GoalRow({required this.progress, required this.pending});

  final GoalProgress progress;
  final List<PlannedBlock> pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => showGoalDetailSheet(context, ref, progress.goal.id),
            behavior: HitTestBehavior.opaque,
            child: GoalBlock(progress: progress),
          ),
        ),
        if (pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.s2),
            child: CompleteGoalButton(
              onTap: () {
                for (final block in trackedBlocksCompletingPlan(pending)) {
                  ref.read(trackedBlocksRepositoryProvider).upsert(block);
                }
              },
            ),
          ),
      ],
    );
  }
}
