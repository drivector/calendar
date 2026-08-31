import 'package:flutter/material.dart'
    show InputBorder, InputDecoration, TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/activity_log.dart';
import '../../../models/goal.dart';
import '../../../models/tracked_block.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';
import '../../goals/widgets/goal_detail_sheet.dart';
import 'log_activity_sheet.dart';

/// Every activity ever tracked, grouped into a day-by-day list (most recent
/// day first; see `models/activity_log.dart`), with a search field to
/// narrow it down by title, goal, or category. Lives inside the Activities
/// tab of the Account screen — logging a new one by hand is now an action
/// on the Day view instead (see [showLogActivitySheet] there).
class ActivitiesList extends ConsumerStatefulWidget {
  const ActivitiesList({super.key});

  @override
  ConsumerState<ActivitiesList> createState() => _ActivitiesListState();
}

class _ActivitiesListState extends ConsumerState<ActivitiesList> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final goals = ref.watch(goalsProvider);
    final allBlocks = ref.watch(allTrackedBlocksProvider);

    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? allBlocks
        : allBlocks.where((block) {
            final goalName = goalForCategory(goals, block.categoryId)?.name ?? '';
            final categoryName = resolveCategory(
              categories,
              block.categoryId,
            ).name;
            return block.title.toLowerCase().contains(query) ||
                goalName.toLowerCase().contains(query) ||
                categoryName.toLowerCase().contains(query);
          }).toList();
    final days = groupTrackedBlocksByDay(filtered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s3,
            AppSpacing.s3,
            AppSpacing.s3,
            0,
          ),
          child: _SearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: days.isEmpty
              ? Center(
                  child: Text(
                    query.isEmpty
                        ? 'No activity yet.'
                        : 'No activities match "${_query.trim()}".',
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
                            key: ValueKey(block.id),
                            block: block,
                            color: resolveCategory(
                              categories,
                              block.categoryId,
                            ).color,
                            goal: goalForCategory(goals, block.categoryId),
                            onTapGoal: (goal) =>
                                showGoalDetailSheet(context, ref, goal.id),
                            onEdit: () => showLogActivitySheet(
                              context,
                              ref,
                              existing: block,
                            ),
                            onDelete: () async {
                              final confirmed = await showConfirmDeleteDialog(
                                context,
                                title: 'Delete activity?',
                                message:
                                    'This removes "${block.title}" from your activity log.',
                              );
                              if (!confirmed) return;
                              await softDeleteTrackedBlock(ref, block);
                            },
                          ),
                        const SizedBox(height: AppSpacing.s3),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.neutral500),
        borderRadius: AppShapes.small,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTextStyles.label(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search by title, goal, or category',
                hintStyle: AppTextStyles.mono(),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s1),
                child: Text('×', style: AppTextStyles.mono()),
              ),
            ),
        ],
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
    super.key,
    required this.block,
    required this.color,
    required this.goal,
    required this.onTapGoal,
    required this.onEdit,
    required this.onDelete,
  });

  final TrackedBlock block;
  final Color color;

  // Null when this block's category doesn't back any goal — a category
  // can exist without one (e.g. right after creation, before a goal is
  // set up for it), so the goal label is just omitted rather than shown
  // as a dead link.
  final Goal? goal;
  final ValueChanged<Goal> onTapGoal;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
            // Its own column, not nested inside the title/goal Row above —
            // that Row already has its own tap target for the goal-name
            // link, and Flutter doesn't stop a tap from also reaching an
            // enclosing GestureDetector, so overlapping the two would fire
            // both on one tap.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatDuration(block.duration),
                  style: AppTextStyles.mono(color: AppColors.text),
                ),
                const SizedBox(height: AppSpacing.s1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onEdit,
                      behavior: HitTestBehavior.opaque,
                      child: Text('edit', style: AppTextStyles.mono()),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    GestureDetector(
                      onTap: onDelete,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'delete',
                        style: AppTextStyles.mono(color: AppColors.accent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
