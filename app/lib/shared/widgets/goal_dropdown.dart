import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../models/goal.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// A single swatch + label row, used both for the trigger (showing the
/// current selection) and for each row in the dropdown's menu.
class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.s1),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.label(),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Sentinel [PopupMenuItem] value for the dropdown's own "+ New goal" row
/// — never a real goal id (those are always `goal-<...>`), so it can't
/// collide with one and needs no separate item type.
const _createGoalValue = '__create_goal__';

/// The goal picker used everywhere a block/entry is filed under a goal
/// (add-block sheet, start-activity sheet, log-activity sheet) — a single
/// bordered field matching this app's other form fields (e.g. `_TimeField`),
/// opening a Fluent-style popup menu of every eligible goal rather than a
/// row of chips, since a longer goal list wraps badly as chips.
class GoalDropdown extends StatelessWidget {
  const GoalDropdown({
    super.key,
    required this.goals,
    required this.colorFor,
    required this.selectedGoalId,
    required this.onChanged,
    this.onCreateGoal,
  });

  final List<Goal> goals;
  final Color Function(Goal goal) colorFor;
  final String? selectedGoalId;
  final ValueChanged<String> onChanged;

  // Optional — when set, the dropdown offers a "+ New goal" row that opens
  // the goal-creation sheet without leaving this one, and selects whatever
  // goal it returns (see [showGoalEditSheet]'s own doc comment on its
  // return value). Omitted where there's nowhere sensible to open that
  // sheet from (there isn't currently such a caller, but the picker itself
  // shouldn't assume there never will be).
  final Future<String?> Function()? onCreateGoal;

  @override
  Widget build(BuildContext context) {
    final selected = selectedGoalId == null
        ? null
        : goals.where((g) => g.id == selectedGoalId).firstOrNull;
    final onCreateGoal = this.onCreateGoal;

    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == _createGoalValue) {
          final createdId = await onCreateGoal!();
          if (createdId != null) onChanged(createdId);
          return;
        }
        onChanged(value);
      },
      color: AppColors.surface,
      elevation: 8,
      padding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
      itemBuilder: (context) => [
        for (final goal in goals)
          PopupMenuItem<String>(
            value: goal.id,
            padding: EdgeInsets.zero,
            height: 40,
            child: Container(
              width: double.infinity,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
              color: goal.id == selectedGoalId ? AppColors.accent100 : null,
              child: Row(
                children: [
                  Expanded(
                    child: _GoalRow(
                      label: goal.name,
                      color: colorFor(goal),
                    ),
                  ),
                  if (goal.id == selectedGoalId)
                    Text('✓', style: AppTextStyles.label(color: AppColors.accent)),
                ],
              ),
            ),
          ),
        if (onCreateGoal != null) ...[
          if (goals.isNotEmpty) const PopupMenuDivider(height: 1),
          PopupMenuItem<String>(
            value: _createGoalValue,
            padding: EdgeInsets.zero,
            height: 40,
            child: Container(
              width: double.infinity,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
              child: Text(
                '+ New goal',
                style: AppTextStyles.label(color: AppColors.accent),
              ),
            ),
          ),
        ],
      ],
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neutral500),
          borderRadius: AppShapes.small,
        ),
        child: Row(
          children: [
            Expanded(
              child: selected == null
                  ? Text('Select a goal', style: AppTextStyles.label(color: AppColors.textSecondary))
                  : _GoalRow(label: selected.name, color: colorFor(selected)),
            ),
            Text('▾', style: AppTextStyles.label(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
