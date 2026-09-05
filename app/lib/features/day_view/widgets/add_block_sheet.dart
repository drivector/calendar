import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_categories.dart';
import '../../../models/goal.dart';
import '../../../models/planned_block.dart';
import '../../../models/tracked_block.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/dashed_border.dart';
import '../../../shared/widgets/goal_dropdown.dart';
import '../../../shared/widgets/inline_form_error.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';
import '../../../utils/time_of_day_utils.dart';

/// Only goals with somewhere real to log against — same exclusion as the
/// Log activity sheet: screen time is auto-tracked, never something you'd
/// manually plan or log by hand.
List<Goal> _eligibleGoals(WidgetRef ref) => ref
    .read(statusActiveGoalsProvider)
    .where((g) => g.categoryId != screenTimeCategoryId)
    .toList();

/// Tapping empty space in a Day view timeline column opens this — a quick
/// add form for a new planned or actual entry, prefilled with the tapped
/// time. Filed under a goal (like the Log activity sheet), not a bare
/// category — the category is derived from whichever goal is picked. No
/// date field — the entry is always for whichever day-column was tapped.
Future<void> showAddBlockSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isPlan,
  required TimeOfDay initialStart,
  required DateTime date,
  TimeOfDay? initialEnd,
  String? initialTitle,
  String? initialGoalId,
  bool fromPlan = false,
  // Set when opening this sheet by tapping an existing manually-added
  // planned block that hasn't happened yet (see TimeBodyGrid) — turns this
  // from "create a new plan" into "edit this one", saving back to the same
  // document (and offering to delete it) instead of adding a duplicate.
  String? editingId,
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
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    // isDismissible stays true (the default) — a barrier tap calls
    // Navigator.maybePop, which does respect the PopScope guard below, so
    // it correctly triggers the same save-or-cancel prompt as any other
    // close attempt. enableDrag stays off: a completed swipe-to-dismiss
    // calls Navigator.pop directly inside Flutter's own
    // BottomSheet.onClosing, bypassing PopScope entirely — see the same
    // note on GoalEditSheet's own sheet, which this mirrors.
    enableDrag: false,
    builder: (context) => _AddBlockSheet(
      isPlan: isPlan,
      initialStart: initialStart,
      date: date,
      ref: ref,
      initialEnd: initialEnd,
      initialTitle: initialTitle,
      initialGoalId: initialGoalId,
      fromPlan: fromPlan,
      editingId: editingId,
    ),
  );
}

class _AddBlockSheet extends StatefulWidget {
  const _AddBlockSheet({
    required this.isPlan,
    required this.initialStart,
    required this.date,
    required this.ref,
    this.initialEnd,
    this.initialTitle,
    this.initialGoalId,
    this.fromPlan = false,
    this.editingId,
  });

  final bool isPlan;
  final TimeOfDay initialStart;
  final DateTime date;
  final WidgetRef ref;

  // Set when opening from an existing planned block (tapping it in the Day
  // view) rather than empty space — prefills the form with that plan's own
  // details instead of leaving it blank, since the whole point of tapping
  // a plan is to log the activity it already describes.
  final TimeOfDay? initialEnd;
  final String? initialTitle;
  final String? initialGoalId;

  // True only when opened by tapping an existing planned block — shows an
  // icon next to the title flagging that this entry matches a plan, rather
  // than being a fresh manual entry.
  final bool fromPlan;

  // Set when editing an existing planned block rather than creating a new
  // one — see showAddBlockSheet's own doc comment on this param.
  final String? editingId;

  @override
  State<_AddBlockSheet> createState() => _AddBlockSheetState();
}

class _AddBlockSheetState extends State<_AddBlockSheet> {
  late final _titleController = TextEditingController(
    text: widget.initialTitle ?? '',
  );
  late TimeOfDay _start = widget.initialStart;
  late TimeOfDay _end = widget.initialEnd ?? addMinutes(widget.initialStart, 30);
  // No default — an eligible goal always exists (the sheet never opens
  // otherwise, see showAddBlockSheet), but which one is the entry actually
  // for is a real choice, not something to guess by picking the first —
  // unless opened from a plan that already names one.
  late String? _goalId = widget.initialGoalId;

  // Shown inline rather than as a SnackBar — see InlineFormError's own doc
  // comment for why a SnackBar doesn't work while this sheet is open.
  String? _errorMessage;

  Duration get _duration {
    final startMinutes = _start.hour * 60 + _start.minute;
    var endMinutes = _end.hour * 60 + _end.minute;
    // Mirrors the overnight rollover _save() applies when it builds the
    // real DateTimes — an end time not after the start time means the
    // entry crosses midnight, not that it's negative-length.
    if (endMinutes <= startMinutes) endMinutes += 24 * 60;
    return Duration(minutes: endMinutes - startMinutes);
  }

  // Captured in initState — eagerly, before any user interaction can
  // happen — so a later close attempt can tell whether the user actually
  // touched anything, the same "close with no changes closes immediately,
  // no confirmation" rule GoalEditSheet follows. A lazy `late` initializer
  // here would be a real bug: it'd only run on first *access*, which could
  // happen after the user had already typed something, silently capturing
  // the edited state as "initial" and making the dirty-check always false.
  late final ({String title, TimeOfDay start, TimeOfDay end, String? goalId})
  _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _initialSnapshot = _snapshot();
  }

  ({String title, TimeOfDay start, TimeOfDay end, String? goalId})
  _snapshot() => (
    title: _titleController.text,
    start: _start,
    end: _end,
    goalId: _goalId,
  );

  bool get _hasUnsavedChanges => _snapshot() != _initialSnapshot;

  Future<void> _handleClose() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final action = await showDialog<_ExitAction>(
      context: context,
      builder: (context) => const _UnsavedActivityDialog(),
    );
    if (!mounted) return;
    switch (action) {
      case _ExitAction.save:
        await _save();
      case _ExitAction.cancel:
        Navigator.of(context).pop();
      case null:
        break; // Dialog dismissed (e.g. its own barrier) — stay put.
    }
  }

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

  Future<void> _save() async {
    final goalId = _goalId;
    if (goalId == null) {
      setState(() => _errorMessage = 'Set a goal before saving');
      return;
    }

    final date = widget.date;
    final startDt = DateTime(
      date.year,
      date.month,
      date.day,
      _start.hour,
      _start.minute,
    );
    var endDt = DateTime(
      date.year,
      date.month,
      date.day,
      _end.hour,
      _end.minute,
    );
    // A safety net for an end time earlier than the start time (e.g. an
    // overnight entry) — advances a day rather than silently recording a
    // negative-duration block.
    if (!endDt.isAfter(startDt)) endDt = endDt.add(const Duration(days: 1));

    final goals = widget.ref.read(goalsProvider);
    final goal = goals.firstWhere((g) => g.id == goalId);
    // An activity name is optional, same as Log Activity — a blank one
    // just falls back to the goal's own name rather than blocking the
    // save, since the goal already says what this is.
    final typedTitle = _titleController.text.trim();
    final title = typedTitle.isEmpty ? goal.name : typedTitle;
    final id = widget.editingId ??
        '${widget.isPlan ? 'plan' : 'actual'}-${DateTime.now().microsecondsSinceEpoch}';

    try {
      if (widget.isPlan) {
        await widget.ref
            .read(plannedBlocksRepositoryProvider)
            .upsert(
              PlannedBlock(
                id: id,
                start: startDt,
                end: endDt,
                title: title,
                goalId: goal.id,
              ),
            );
      } else {
        await widget.ref
            .read(trackedBlocksRepositoryProvider)
            .upsert(
              TrackedBlock(
                id: id,
                start: startDt,
                end: endDt,
                title: title,
                goalId: goal.id,
                sourceId: 'manual',
              ),
            );
      }
    } catch (_) {
      // The write used to be fired and forgotten, with the sheet closing
      // immediately either way — so a rejected write (the real case:
      // Firestore rules validating a field the app had stopped writing)
      // looked exactly like a successful save that produced nothing.
      // Surface it and stay open instead, matching the Start-activity
      // sheet and the Account tracking-window save.
      if (mounted) setState(() => _errorMessage = kSaveFailedMessage);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete planned activity?',
      message: 'This removes "${_titleController.text}" from your plan.',
    );
    if (!confirmed || !mounted) return;
    await widget.ref
        .read(plannedBlocksRepositoryProvider)
        .remove(widget.editingId!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // A read, not a watch — see the note on the same pattern in
    // GoalEditSheet: this ref belongs to the widget that opened this sheet.
    final categories = widget.ref.read(categoriesProvider);
    final goals = _eligibleGoals(widget.ref);

    return PopScope(
      canPop: false,
      // A tap on the modal barrier calls Navigator.maybePop, which routes
      // through here too — that's what makes "tap elsewhere" open the same
      // save-or-cancel prompt as any other close attempt, rather than
      // silently discarding the draft.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: Padding(
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              widget.editingId != null
                                  ? 'Edit planned activity'
                                  : widget.isPlan
                                  ? 'New planned activity'
                                  : 'New actual activity',
                              style: AppTextStyles.title(),
                            ),
                            const SizedBox(width: AppSpacing.s2),
                            // Auto-calculated from start/end time — never a
                            // field of its own, so it lives next to the
                            // title rather than taking up a third column.
                            Text(
                              '· ${formatDuration(_duration)}',
                              style: AppTextStyles.mono(),
                            ),
                            if (widget.fromPlan) ...[
                              const SizedBox(width: AppSpacing.s2),
                              const _MatchesPlanIcon(),
                            ],
                          ],
                        ),
                        GestureDetector(
                          onTap: _save,
                          behavior: HitTestBehavior.opaque,
                          child: Text('save', style: AppTextStyles.mono()),
                        ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.s3),
                      InlineFormError(_errorMessage!),
                    ],
                    const SizedBox(height: AppSpacing.s3),
                    _Label('Activity'),
                    TextField(
                      controller: _titleController,
                      style: AppTextStyles.label(),
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(
                            label: 'Start time',
                            value: _start,
                            onTap: () => _pickTime(true),
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
                    GoalDropdown(
                      goals: goals,
                      colorFor: (goal) => resolveCategory(categories, goal.categoryId).color,
                      selectedGoalId: _goalId,
                      onChanged: (goalId) => setState(() {
                        _goalId = goalId;
                        _errorMessage = null;
                      }),
                    ),
                    if (widget.editingId != null) ...[
                      const SizedBox(height: AppSpacing.s3),
                      GestureDetector(
                        onTap: _delete,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Delete planned activity',
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
      ),
    );
  }
}

enum _ExitAction { save, cancel }

/// Offers save/cancel before letting the add-block sheet close with
/// unsaved changes — flat, bordered, no rounded corners, matching the
/// sheet it sits over rather than Material's default dialog chrome. Two
/// options, not three: unlike GoalEditSheet (which can be re-entered to
/// keep editing an existing goal), this sheet is a one-shot quick-add —
/// there's nothing to "keep editing" that isn't already fully visible.
class _UnsavedActivityDialog extends StatelessWidget {
  const _UnsavedActivityDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
      child: DecoratedBox(
        decoration: const BoxDecoration(borderRadius: AppShapes.medium),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Save this activity?', style: AppTextStyles.title()),
              const SizedBox(height: AppSpacing.s1),
              Text(
                'You have unsaved changes.',
                style: AppTextStyles.mono(),
              ),
              const SizedBox(height: AppSpacing.s4),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(_ExitAction.save),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: AppShapes.small,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3,
                  ),
                  child: Text(
                    'Save',
                    style: AppTextStyles.small(color: AppColors.surface),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(_ExitAction.cancel),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.text),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3,
                  ),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.small(color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small dashed-outline check mark, shown next to the sheet's title only
/// when it was opened by tapping an existing planned block — echoes
/// [PlanBlockWidget]'s own dashed-outline styling so it reads as "this
/// matches a plan" at a glance, with a [Tooltip] spelling that out for
/// anyone who isn't sure what the glyph means.
class _MatchesPlanIcon extends StatelessWidget {
  const _MatchesPlanIcon();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Matches a planned activity',
      child: DashedRectBorder(
        color: AppColors.accent,
        radius: const Radius.circular(9),
        child: SizedBox(
          width: 18,
          height: 18,
          child: Center(
            child: Text(
              '✓',
              style: AppTextStyles.small(color: AppColors.accent),
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
              border: Border.all(color: AppColors.neutral500), borderRadius: AppShapes.small,
            ),
            child: Text(value.format(context), style: AppTextStyles.label()),
          ),
        ),
      ],
    );
  }
}

