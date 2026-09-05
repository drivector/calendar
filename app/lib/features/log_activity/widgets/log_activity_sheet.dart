import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../data/mock/mock_categories.dart';
import '../../../models/goal.dart';
import '../../../data/firestore/firestore_list_repository.dart';
import '../../../models/tracked_block.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/goal_dropdown.dart';
import '../../../shared/widgets/inline_form_error.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../state/log_entry_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';

/// The manual-entry form (screen 5, "Log activity") — the "+ LOG" action
/// on the Activities screen, and also how an existing entry there gets
/// edited. Pass [existing] to edit that block in place (with a delete
/// option); omit it to create a new one. Saving writes a real
/// [TrackedBlock] and closes the sheet; the change shows up in the
/// Activities list immediately, since both read the same live provider.
Future<void> showLogActivitySheet(
  BuildContext context,
  WidgetRef ref, {
  TrackedBlock? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (context) => LogActivitySheet(ref: ref, existing: existing),
  ).then((_) {
    // Belt-and-braces reset: _close/_save/_delete already reset the draft
    // on their own way out, but a scrim tap or drag-to-dismiss bypasses
    // all three, leaving a stale date (or other fields) behind for the
    // *next* open to silently pick up instead of defaulting to today. See
    // `if (draftLogEntryProvider.date == null)` below — this reset is
    // what makes that guard actually see a fresh draft every time.
    ref.read(draftLogEntryProvider.notifier).reset();
  });
}

class LogActivitySheet extends ConsumerStatefulWidget {
  const LogActivitySheet({super.key, required this.ref, this.existing});

  // The WidgetRef the sheet was opened from — read-only in here (see the
  // Riverpod gotcha this project follows: a borrowed ref must use .read(),
  // never .watch(), inside this widget's own build). Reactive state below
  // goes through this state's own [ref] instead.
  final WidgetRef ref;

  final TrackedBlock? existing;

  @override
  ConsumerState<LogActivitySheet> createState() => _LogActivitySheetState();
}

class _LogActivitySheetState extends ConsumerState<LogActivitySheet> {
  // Shown inline rather than as a SnackBar — see InlineFormError's own doc
  // comment for why a SnackBar doesn't work while this sheet is open.
  String? _errorMessage;

  // The Activity/Note fields are plain TextFields driven by onChanged into
  // the draft provider, with no controller of their own — fine for a
  // fresh, blank create, but an edit needs to *display* the existing
  // title/note, and an uncontrolled TextField has no way to be told what
  // text to start with. These controllers are that: seeded from
  // [widget.existing] synchronously in initState (a TextEditingController
  // isn't a provider, so this doesn't hit the "no provider writes in
  // initState" rule the draft prefill below does).
  late final _activityController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _noteController = TextEditingController(
    text: widget.existing?.note ?? '',
  );

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame: Riverpod forbids modifying a
    // provider from initState itself.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final existing = widget.existing;
      final notifier = widget.ref.read(draftLogEntryProvider.notifier);
      if (existing != null) {
        // Editing — the draft always starts empty on a fresh open, so
        // this fully repopulates it from the block being edited rather
        // than just defaulting the date.
        final goal = goalById(widget.ref.read(goalsProvider), existing.goalId);
        notifier
          ..setDate(
            DateTime(
              existing.start.year,
              existing.start.month,
              existing.start.day,
            ),
          )
          ..setActivity(existing.title)
          ..setStart(TimeOfDay.fromDateTime(existing.start))
          ..setEnd(TimeOfDay.fromDateTime(existing.end))
          ..setNote(existing.note ?? '');
        if (goal != null) notifier.setGoal(goal.id);
      } else if (widget.ref.read(draftLogEntryProvider).date == null) {
        // Creating — defaults to whatever day the app is currently
        // showing (both _close and _save reset the draft, so this only
        // ever fires once per open, never overwriting a day the user
        // already picked).
        notifier.setDate(widget.ref.read(selectedDateProvider));
      }
    });
  }

  @override
  void dispose() {
    _activityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _close() {
    widget.ref.read(draftLogEntryProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
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
      setState(
        () => _errorMessage = 'Set ${missing.join(' and ')} before saving',
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

    final existing = widget.existing;
    try {
      await widget.ref
          .read(trackedBlocksRepositoryProvider)
          .upsert(
            TrackedBlock(
              id: existing?.id ??
                  'manual-${DateTime.now().microsecondsSinceEpoch}',
              start: startDt,
              end: endDt,
              title: title,
              goalId: goal.id,
              // Editing keeps the block's real provenance (a health/calendar
              // import stays that, not relabeled "manual" just because it
              // was touched) and its link back to a plan, if it had one.
              sourceId: existing?.sourceId ?? 'manual',
              confidence: existing?.confidence ?? 1.0,
              plannedBlockId: existing?.plannedBlockId,
              note: draft.note.trim().isEmpty ? null : draft.note.trim(),
            ),
          );
    } catch (_) {
      // Not awaited before, so a rejected write closed this sheet exactly
      // as a successful one did — the entry simply never appeared in the
      // Activities list. The draft is deliberately left intact so the
      // retry doesn't start from a blank form.
      if (mounted) setState(() => _errorMessage = kSaveFailedMessage);
      return;
    }

    widget.ref.read(draftLogEntryProvider.notifier).reset();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete activity?',
      message: 'This removes "${existing.title}" from your activity log.',
    );
    if (!confirmed || !mounted) return;

    try {
      await softDeleteTrackedBlock(widget.ref, existing);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = kDeleteFailedMessage);
      return;
    }
    widget.ref.read(draftLogEntryProvider.notifier).reset();
    if (!mounted) return;
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
                        _isEditing ? 'Edit activity' : 'Log activity',
                        style: AppTextStyles.title(),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _close,
                            behavior: HitTestBehavior.opaque,
                            child: Text('close', style: AppTextStyles.mono()),
                          ),
                          const SizedBox(width: AppSpacing.s3),
                          // Save lives in the header next to close, not as
                          // a separate full-width button below the form —
                          // matches the add-block sheet's own header
                          // save/close convention.
                          GestureDetector(
                            onTap: _save,
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              _isEditing ? 'Save changes' : 'Save entry',
                              style: AppTextStyles.mono(color: AppColors.accent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.s3),
                    InlineFormError(_errorMessage!),
                  ],
                  const SizedBox(height: AppSpacing.s3),
                  _FieldLabel('Day'),
                  DateField(
                    value: draft.date,
                    onPick: (value) {
                      notifier.setDate(value);
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                    firstDate: DateTime(2020, 1, 1),
                    lastDate: DateTime.now(),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _FieldLabel('Activity'),
                  TextField(
                    controller: _activityController,
                    style: AppTextStyles.label(),
                    decoration: const InputDecoration(isDense: true),
                    // See the same cap on the add-block sheet's own title.
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(kMaxFieldLength),
                    ],
                    onChanged: notifier.setActivity,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          label: 'Start',
                          value: draft.start,
                          onPick: (value) {
                            notifier.setStart(value);
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: _TimeField(
                          label: 'End',
                          value: draft.end,
                          onPick: (value) {
                            notifier.setEnd(value);
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
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
                  GoalDropdown(
                    // Logging is goal-first, not category-first — the
                    // screen-time goal is excluded since it's auto-tracked,
                    // not something you'd manually log.
                    goals: goals
                        .where(
                          (g) =>
                              g.categoryId != screenTimeCategoryId &&
                              g.status == GoalLifecycleStatus.active,
                        )
                        .toList(),
                    colorFor: (goal) => resolveCategory(categories, goal.categoryId).color,
                    selectedGoalId: draft.goalId,
                    onChanged: (goalId) {
                      notifier.setGoal(goalId);
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                  ),
                  if (selectedGoal != null) ...[
                    const SizedBox(height: AppSpacing.s3),
                    // A byDate goal has no repeating week to speak of —
                    // its own total across every day it's actually been
                    // given entries for instead (see Goal.totalTarget's
                    // own doc comment).
                    if (selectedGoal.scheduleMode == GoalScheduleMode.byDate) ...[
                      _FieldLabel('Total target'),
                      Text(
                        formatDuration(selectedGoal.totalTarget),
                        style: AppTextStyles.mono(color: AppColors.text),
                      ),
                    ] else ...[
                      _FieldLabel('Weekly target'),
                      Text(
                        '${formatDuration(selectedGoal.weeklyTarget)}/wk',
                        style: AppTextStyles.mono(color: AppColors.text),
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.s3),
                  _FieldLabel('Note'),
                  TextField(
                    controller: _noteController,
                    minLines: 3,
                    maxLines: 5,
                    style: AppTextStyles.label(),
                    decoration: const InputDecoration(isDense: true),
                    onChanged: notifier.setNote,
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: AppSpacing.s4),
                    GestureDetector(
                      onTap: _delete,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 44),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Delete activity',
                          style: AppTextStyles.small(color: AppColors.accent),
                        ),
                      ),
                    ),
                  ],
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
              border: Border.all(color: AppColors.neutral500), borderRadius: AppShapes.small,
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
