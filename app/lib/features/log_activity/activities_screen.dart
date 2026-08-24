import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/activity_log.dart';
import '../../models/goal.dart';
import '../../models/tracked_block.dart';
import '../../shared/widgets/date_swipe_nav.dart';
import '../../state/categories_providers.dart';
import '../../state/day_view_providers.dart';
import '../../state/goals_providers.dart';
import '../../state/root_shell_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/duration_format.dart';
import '../goals/widgets/goal_detail_sheet.dart';
import 'widgets/log_activity_sheet.dart';

/// Screen 4 (renamed from the former "+ Log" tab) — every activity ever
/// tracked, grouped into a day-by-day list (most recent day first; see
/// `models/activity_log.dart`) rather than only ever showing one day at a
/// time. Logging a new one by hand is an action on this page ("+ LOG",
/// opens [showLogActivitySheet]) rather than the whole tab.
class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final goals = ref.watch(goalsProvider);
    final days = groupTrackedBlocksByDay(ref.watch(allTrackedBlocksProvider));

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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Activities', style: AppTextStyles.title()),
                    GestureDetector(
                      onTap: () => showLogActivitySheet(context, ref),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 32),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.text, width: 1.5),
                        ),
                        child: Text(
                          '+ LOG',
                          style: AppTextStyles.small(color: AppColors.text),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: days.isEmpty
                  ? Center(
                      child: Text(
                        'No activity yet.',
                        style: AppTextStyles.mono(),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.s3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final group in days) ...[
                            _DaySectionHeader(day: group.day),
                            const SizedBox(height: AppSpacing.s1),
                            for (final block in group.blocks)
                              _ActivityRow(
                                block: block,
                                color: resolveCategory(
                                  categories,
                                  block.categoryId,
                                ).color,
                                goal: goalForCategory(goals, block.categoryId),
                                onTapGoal: (goal) =>
                                    showGoalDetailSheet(context, ref, goal.id),
                              ),
                            const SizedBox(height: AppSpacing.s3),
                          ],
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

class _DaySectionHeader extends StatelessWidget {
  const _DaySectionHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s2),
        child: Text(
          DateFormat('EEEE, d MMM').format(day).toUpperCase(),
          style: AppTextStyles.kicker(),
        ),
      ),
    );
  }
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.block,
    required this.color,
    required this.goal,
    required this.onTapGoal,
  });

  final TrackedBlock block;
  final Color color;

  // Null when this block's category doesn't back any goal — a category
  // can exist without one (e.g. right after creation, before a goal is
  // set up for it), so the goal label is just omitted rather than shown
  // as a dead link.
  final Goal? goal;
  final ValueChanged<Goal> onTapGoal;

  @override
  Widget build(BuildContext context) {
    final goal = this.goal;
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(block.title, style: AppTextStyles.label()),
                      if (goal != null) ...[
                        const SizedBox(width: AppSpacing.s1),
                        GestureDetector(
                          onTap: () => onTapGoal(goal),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            goal.name,
                            style: AppTextStyles.mono(color: AppColors.accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${_clock(block.start)}–${_clock(block.end)} · ${block.sourceId}',
                    style: AppTextStyles.mono(),
                  ),
                  if (block.note != null && block.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(block.note!, style: AppTextStyles.mono()),
                  ],
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
