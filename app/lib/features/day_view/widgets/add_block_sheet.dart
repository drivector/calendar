import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_categories.dart';
import '../../../models/goal.dart';
import '../../../models/planned_block.dart';
import '../../../models/tracked_block.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/time_of_day_utils.dart';

/// Only goals with somewhere real to log against — same exclusion as the
/// Log activity sheet: screen time is auto-tracked, never something you'd
/// manually plan or log by hand.
List<Goal> _eligibleGoals(WidgetRef ref) => ref
    .read(goalsProvider)
    .where((g) => g.categoryId != screenTimeCategoryId)
    .toList();

/// Tapping empty space in either lane of the Day view timeline opens this —
/// a quick add form for a new planned or actual entry, prefilled with the
/// tapped time. Filed under a goal (like the Log activity sheet), not a
/// bare category — the category is derived from whichever goal is picked.
Future<void> showAddBlockSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isPlan,
  required TimeOfDay initialStart,
}) {
  // Nothing to file a block under yet — a brand-new account starts with no
  // goals, so tell the user to create one first rather than opening a form
  // with no valid default.
  if (_eligibleGoals(ref).isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Create a goal first')));
    return Future.value();
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    isScrollControlled: true,
    builder: (context) =>
        _AddBlockSheet(isPlan: isPlan, initialStart: initialStart, ref: ref),
  );
}

class _AddBlockSheet extends StatefulWidget {
  const _AddBlockSheet({
    required this.isPlan,
    required this.initialStart,
    required this.ref,
  });

  final bool isPlan;
  final TimeOfDay initialStart;
  final WidgetRef ref;

  @override
  State<_AddBlockSheet> createState() => _AddBlockSheetState();
}

class _AddBlockSheetState extends State<_AddBlockSheet> {
  late final _titleController = TextEditingController();
  late DateTime _startDate = widget.ref.read(selectedDateProvider);
  late DateTime _endDate = widget.ref.read(selectedDateProvider);
  late TimeOfDay _start = widget.initialStart;
  late TimeOfDay _end = addMinutes(widget.initialStart, 30);
  late String? _goalId = _eligibleGoals(widget.ref).firstOrNull?.id;

  // A planned block can reasonably sit in the future; a manually-logged
  // actual one can't.
  DateTime get _dateUpperBound => widget.isPlan
      ? DateTime.now().add(const Duration(days: 365))
      : DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _save() {
    final goalId = _goalId;
    if (goalId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Set a goal before saving')));
      return;
    }

    final startDt = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _start.hour,
      _start.minute,
    );
    var endDt = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _end.hour,
      _end.minute,
    );
    // A safety net for whoever leaves the end date untouched with an
    // end time earlier than the start time — advances a day rather than
    // silently recording a negative-duration block.
    if (!endDt.isAfter(startDt)) endDt = endDt.add(const Duration(days: 1));

    final goals = widget.ref.read(goalsProvider);
    final goal = goals.firstWhere((g) => g.id == goalId);
    final title = _titleController.text.trim().isEmpty
        ? goal.name
        : _titleController.text.trim();
    final id =
        '${widget.isPlan ? 'plan' : 'actual'}-${DateTime.now().microsecondsSinceEpoch}';

    if (widget.isPlan) {
      widget.ref
          .read(plannedBlocksRepositoryProvider)
          .upsert(
            PlannedBlock(
              id: id,
              start: startDt,
              end: endDt,
              title: title,
              categoryId: goal.categoryId,
            ),
          );
    } else {
      widget.ref
          .read(trackedBlocksRepositoryProvider)
          .upsert(
            TrackedBlock(
              id: id,
              start: startDt,
              end: endDt,
              title: title,
              categoryId: goal.categoryId,
              sourceId: 'manual',
            ),
          );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // A read, not a watch — see the note on the same pattern in
    // GoalEditSheet: this ref belongs to the widget that opened this sheet.
    final categories = widget.ref.read(categoriesProvider);
    final goals = _eligibleGoals(widget.ref);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DecoratedBox(
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
                      Text(
                        widget.isPlan
                            ? 'New planned activity'
                            : 'New actual activity',
                        style: AppTextStyles.title(),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Text('cancel', style: AppTextStyles.mono()),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _Label('Activity'),
                  TextField(
                    controller: _titleController,
                    style: AppTextStyles.label(),
                    decoration: const InputDecoration(isDense: true),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Label('Start date'),
                            DateField(
                              value: _startDate,
                              onPick: (value) =>
                                  setState(() => _startDate = value),
                              firstDate: DateTime(2020, 1, 1),
                              lastDate: _dateUpperBound,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: _TimeField(
                          label: 'Start time',
                          value: _start,
                          onTap: () => _pickTime(true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Label('End date'),
                            DateField(
                              value: _endDate,
                              onPick: (value) =>
                                  setState(() => _endDate = value),
                              firstDate: DateTime(2020, 1, 1),
                              lastDate: _dateUpperBound,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: _TimeField(
                          label: 'End time',
                          value: _end,
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _Label('Goal'),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: [
                      for (final goal in goals)
                        CategoryChip(
                          label: goal.name.toLowerCase(),
                          color: resolveCategory(
                            categories,
                            goal.categoryId,
                          ).color,
                          selected: _goalId == goal.id,
                          onTap: () => setState(() => _goalId = goal.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  GestureDetector(
                    onTap: _save,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.centerLeft,
                      color: AppColors.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s3,
                      ),
                      child: Text(
                        widget.isPlan ? 'ADD PLAN' : 'ADD ACTUAL',
                        style: AppTextStyles.small(color: AppColors.bg),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text.toUpperCase(), style: AppTextStyles.kicker()),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Label(label),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(value.format(context), style: AppTextStyles.label()),
          ),
        ),
      ],
    );
  }
}
