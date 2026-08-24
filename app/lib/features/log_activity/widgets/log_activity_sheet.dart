import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_categories.dart';
import '../../../models/goal.dart';
import '../../../models/tracked_block.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../state/log_entry_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';

/// The manual-entry form (screen 5, "Log activity") — the "+ LOG" action
/// on the Activities screen. Saving creates a real [TrackedBlock] for the
/// currently selected day and closes the sheet; the new entry shows up in
/// the Activities list immediately, since both read the same live provider.
Future<void> showLogActivitySheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    isScrollControlled: true,
    builder: (context) => LogActivitySheet(ref: ref),
  );
}

class LogActivitySheet extends ConsumerStatefulWidget {
  const LogActivitySheet({super.key, required this.ref});

  // The WidgetRef the sheet was opened from — read-only in here (see the
  // Riverpod gotcha this project follows: a borrowed ref must use .read(),
  // never .watch(), inside this widget's own build). Reactive state below
  // goes through this state's own [ref] instead.
  final WidgetRef ref;

  @override
  ConsumerState<LogActivitySheet> createState() => _LogActivitySheetState();
}

class _LogActivitySheetState extends ConsumerState<LogActivitySheet> {
  @override
  void initState() {
    super.initState();
    // Defaults to whatever day the app is currently showing — the draft
    // always starts empty on a fresh open (both _close and _save reset it),
    // so this only ever fires once per open, never overwriting a day the
    // user already picked. Deferred to after the first frame: Riverpod
    // forbids modifying a provider from initState itself.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.ref.read(draftLogEntryProvider).date == null) {
        widget.ref
            .read(draftLogEntryProvider.notifier)
            .setDate(widget.ref.read(selectedDateProvider));
      }
    });
  }

  void _close() {
    widget.ref.read(draftLogEntryProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  void _save() {
    final draft = widget.ref.read(draftLogEntryProvider);
    final date = draft.date;
    final start = draft.start;
    final end = draft.end;
    final goalId = draft.goalId;

    // Previously a silent no-op: tapping SAVE ENTRY with any of these
    // unset just closed the sheet as if it had worked, with nothing
    // actually written — easy to trigger by accident (e.g. filling in the
    // day and activity name but forgetting start/end or a goal) and
    // impossible to notice without checking the Activities list
    // afterward. Now it stays open and says what's still missing instead.
    final missing = [
      if (date == null) 'a day',
      if (start == null || end == null) 'a start and end time',
      if (goalId == null) 'a goal',
    ];
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Set ${missing.join(' and ')} before saving')),
      );
      return;
    }

    final startDt = DateTime(
      date!.year,
      date.month,
      date.day,
      start!.hour,
      start.minute,
    );
    var endDt = DateTime(
      date.year,
      date.month,
      date.day,
      end!.hour,
      end.minute,
    );
    if (!endDt.isAfter(startDt)) endDt = endDt.add(const Duration(days: 1));

    final goals = widget.ref.read(goalsProvider);
    final goal = goals.firstWhere((g) => g.id == goalId);
    final title = draft.activity.trim().isEmpty
        ? goal.name
        : draft.activity.trim();

    widget.ref
        .read(trackedBlocksRepositoryProvider)
        .upsert(
          TrackedBlock(
            id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
            start: startDt,
            end: endDt,
            title: title,
            categoryId: goal.categoryId,
            sourceId: 'manual',
          ),
        );

    widget.ref.read(draftLogEntryProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftLogEntryProvider);
    final notifier = ref.read(draftLogEntryProvider.notifier);
    final categories = ref.watch(categoriesProvider);
    final goals = ref.watch(goalsProvider);
    Goal? selectedGoal;
    for (final goal in goals) {
      if (goal.id == draft.goalId) {
        selectedGoal = goal;
        break;
      }
    }

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
                      Text('Log activity', style: AppTextStyles.title()),
                      GestureDetector(
                        onTap: _close,
                        behavior: HitTestBehavior.opaque,
                        child: Text('close', style: AppTextStyles.mono()),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _FieldLabel('Day'),
                  DateField(
                    value: draft.date,
                    onPick: notifier.setDate,
                    firstDate: DateTime(2020, 1, 1),
                    lastDate: DateTime.now(),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _FieldLabel('Activity'),
                  TextField(
                    style: AppTextStyles.label(),
                    decoration: const InputDecoration(isDense: true),
                    onChanged: notifier.setActivity,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          label: 'Start',
                          value: draft.start,
                          onPick: notifier.setStart,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: _TimeField(
                          label: 'End',
                          value: draft.end,
                          onPick: notifier.setEnd,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _FieldLabel('Duration'),
                  Text(
                    draft.duration == null
                        ? '—'
                        : formatDuration(draft.duration!),
                    style: AppTextStyles.title().copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    child: const SizedBox(width: double.infinity, height: 1),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _FieldLabel('Goal'),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: [
                      // Logging is goal-first, not category-first — the
                      // screen-time goal is excluded since it's auto-tracked,
                      // not something you'd manually log.
                      for (final goal in goals.where(
                        (g) => g.categoryId != screenTimeCategoryId,
                      ))
                        CategoryChip(
                          label: goal.name.toLowerCase(),
                          color: resolveCategory(
                            categories,
                            goal.categoryId,
                          ).color,
                          selected: draft.goalId == goal.id,
                          onTap: () => notifier.setGoal(goal.id),
                        ),
                    ],
                  ),
                  if (selectedGoal != null) ...[
                    const SizedBox(height: AppSpacing.s3),
                    _FieldLabel('Weekly target'),
                    Text(
                      '${formatDuration(selectedGoal.weeklyTarget)}/wk',
                      style: AppTextStyles.mono(color: AppColors.text),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s3),
                  _FieldLabel('Note'),
                  TextField(
                    minLines: 3,
                    maxLines: 5,
                    style: AppTextStyles.label(),
                    decoration: const InputDecoration(isDense: true),
                    onChanged: notifier.setNote,
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
                        'SAVE ENTRY',
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

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
    required this.onPick,
  });

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel(label),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: value ?? TimeOfDay.now(),
            );
            if (picked != null) onPick(picked);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              value == null
                  ? 'Set $label'.toLowerCase()
                  : value!.format(context),
              style: AppTextStyles.label(),
            ),
          ),
        ),
      ],
    );
  }
}
