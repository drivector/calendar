import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/clock_time.dart';
import '../../../models/goal.dart';
import '../../../models/goal_progress.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../shared/widgets/segmented_control.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';

const _step = Duration(minutes: 5);
const _minPerEntry = Duration(minutes: 5);
const _maxPerEntry = Duration(hours: 8);
const _defaultRangeStart = TimeOfDay(hour: 9, minute: 0);
const _defaultRangeEnd = TimeOfDay(hour: 17, minute: 0);

Map<int, List<DayScheduleEntry>> _defaultSchedule() => {
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: [const DayScheduleEntry.duration(Duration(minutes: 30))],
    };

/// Create or edit a goal. Pass [existing] to edit it in place (with a
/// delete option); omit it to create a new one.
Future<void> showGoalEditSheet(
  BuildContext context,
  WidgetRef ref, {
  Goal? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    isScrollControlled: true,
    builder: (context) => GoalEditSheet(existing: existing, ref: ref),
  );
}

class GoalEditSheet extends StatefulWidget {
  const GoalEditSheet({super.key, this.existing, required this.ref});

  final Goal? existing;
  final WidgetRef ref;

  @override
  State<GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<GoalEditSheet> {
  late final _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late String _categoryId =
      widget.existing?.categoryId ?? widget.ref.read(categoriesProvider).first.id;
  late GoalType _type = widget.existing?.type ?? GoalType.target;
  // Defaults to the day the app is currently showing, not the device's real
  // clock — the app's own "today" (`selectedDateProvider`) is what decides
  // whether a goal is active, so a brand-new goal should start there, or it
  // can be filtered out as "not started yet" the instant it's created.
  late DateTime _startDate =
      widget.existing?.startDate ?? widget.ref.read(selectedDateProvider);
  late DateTime _endDate =
      widget.existing?.endDate ?? _startDate.add(ongoingGoalSpan);

  // One unified per-day schedule — each day holds a list of entries, each
  // either a plain duration or a clock time range, summed for that day's
  // target. A deep-enough copy (fresh lists) so editing here never mutates
  // the goal still sitting in the provider until Save is tapped.
  late final Map<int, List<DayScheduleEntry>> _schedule = {
    for (var weekday = 1; weekday <= 7; weekday++)
      weekday: List.of(
        widget.existing?.entriesForWeekday(weekday) ??
            _defaultSchedule()[weekday]!,
      ),
  };

  bool get _isEditing => widget.existing != null;

  Duration _dayTotal(int weekday) => (_schedule[weekday] ?? const [])
      .fold(Duration.zero, (total, e) => total + e.effectiveDuration);

  Duration get _weeklyTotal => [
        for (var weekday = 1; weekday <= 7; weekday++) _dayTotal(weekday),
      ].fold(Duration.zero, (a, b) => a + b);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addDurationEntry(int weekday) {
    setState(() {
      _schedule[weekday]!.add(const DayScheduleEntry.duration(Duration(minutes: 30)));
    });
  }

  Future<void> _addTimeRangeEntry(int weekday) async {
    final start = await showTimePicker(context: context, initialTime: _defaultRangeStart);
    if (start == null || !mounted) return;
    final end = await showTimePicker(context: context, initialTime: _defaultRangeEnd);
    if (end == null) return;
    setState(() {
      _schedule[weekday]!.add(DayScheduleEntry.timeRange(ClockRange(
        ClockTime(start.hour, start.minute),
        ClockTime(end.hour, end.minute),
      )));
    });
  }

  void _removeEntry(int weekday, int index) {
    setState(() => _schedule[weekday]!.removeAt(index));
  }

  void _stepDurationEntry(int weekday, int index, int deltaMinutes) {
    setState(() {
      final entries = _schedule[weekday]!;
      final current = entries[index].duration!;
      final next = current + Duration(minutes: deltaMinutes);
      final clamped = next < _minPerEntry
          ? _minPerEntry
          : (next > _maxPerEntry ? _maxPerEntry : next);
      entries[index] = DayScheduleEntry.duration(clamped);
    });
  }

  Future<void> _editRangeStart(int weekday, int index) async {
    final current = _schedule[weekday]![index].timeRange!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.start.hour, minute: current.start.minute),
    );
    if (picked == null) return;
    setState(() {
      _schedule[weekday]![index] = DayScheduleEntry.timeRange(
        ClockRange(ClockTime(picked.hour, picked.minute), current.end),
      );
    });
  }

  Future<void> _editRangeEnd(int weekday, int index) async {
    final current = _schedule[weekday]![index].timeRange!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.end.hour, minute: current.end.minute),
    );
    if (picked == null) return;
    setState(() {
      _schedule[weekday]![index] = DayScheduleEntry.timeRange(
        ClockRange(current.start, ClockTime(picked.hour, picked.minute)),
      );
    });
  }

  void _applySameEveryDay() {
    setState(() {
      final mondayEntries =
          List.of(_schedule[DateTime.monday] ?? const <DayScheduleEntry>[]);
      for (var weekday = 1; weekday <= 7; weekday++) {
        _schedule[weekday] = List.of(mondayEntries);
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  void _save() {
    final goal = Goal(
      id: widget.existing?.id ?? 'goal-${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty
          ? 'Untitled goal'
          : _nameController.text.trim(),
      categoryId: _categoryId,
      type: _type,
      scheduleByWeekday: {
        for (var weekday = 1; weekday <= 7; weekday++)
          weekday: List.of(_schedule[weekday] ?? const []),
      },
      startDate: _startDate,
      endDate: _endDate,
    );
    if (_isEditing) {
      widget.ref.read(goalsProvider.notifier).updateGoal(goal);
    } else {
      widget.ref.read(goalsProvider.notifier).addGoal(goal);
    }
    Navigator.of(context).pop();
  }

  void _delete() {
    widget.ref.read(goalsProvider.notifier).removeGoal(widget.existing!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // A read, not a watch: this ref belongs to the widget that opened this
    // sheet, not this one — watching from a borrowed ref outside its own
    // build risks a Riverpod assertion. A snapshot is fine for a short-lived
    // modal the category list won't change while it's open.
    final categories = widget.ref.read(categoriesProvider);
    // The actual calendar date for each weekday row — the week containing
    // whatever day the app currently has open, so "Mon" reads as a real
    // date, not an abstract day-of-week.
    final weekStart = weekStartFor(widget.ref.read(selectedDateProvider));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                        _isEditing ? 'Edit goal' : 'New goal',
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
                  _Label('Name'),
                  TextField(
                    controller: _nameController,
                    style: AppTextStyles.label(),
                    decoration: const InputDecoration(isDense: true),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _Label('Category'),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: [
                      for (final category in categories)
                        CategoryChip(
                          label: category.name.toLowerCase(),
                          color: category.color,
                          selected: _categoryId == category.id,
                          onTap: () => setState(() => _categoryId = category.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _Label('Type'),
                  SegmentedControl<GoalType>(
                    selected: _type,
                    onChanged: (value) => setState(() => _type = value),
                    options: const [
                      SegmentedOption(value: GoalType.target, label: 'Target'),
                      SegmentedOption(value: GoalType.cap, label: 'Cap'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _Label('Dates'),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Start date',
                          value: _startDate,
                          onTap: () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: _DateField(
                          label: 'End date',
                          value: _endDate,
                          onTap: () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    'leave the default end date for an ongoing habit; shorten it for a dated challenge',
                    style: AppTextStyles.mono(),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _Label('Daily targets'),
                      _SmallActionButton(label: 'same every day', onTap: _applySameEveryDay),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    'each day can mix any number of plain durations and time '
                    'ranges — a time range\'s duration is derived from its clock '
                    'times automatically',
                    style: AppTextStyles.mono(),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  for (var weekday = 1; weekday <= 7; weekday++)
                    _DayScheduleSection(
                      label: DateFormat('EEE d MMM')
                          .format(weekStart.add(Duration(days: weekday - 1))),
                      entries: _schedule[weekday] ?? const [],
                      total: _dayTotal(weekday),
                      onAddDuration: () => _addDurationEntry(weekday),
                      onAddTimeRange: () => _addTimeRangeEntry(weekday),
                      onRemove: (index) => _removeEntry(weekday, index),
                      onStepDuration: (index, delta) =>
                          _stepDurationEntry(weekday, index, delta),
                      onEditRangeStart: (index) => _editRangeStart(weekday, index),
                      onEditRangeEnd: (index) => _editRangeEnd(weekday, index),
                    ),
                  const SizedBox(height: AppSpacing.s1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('WEEKLY TOTAL', style: AppTextStyles.kicker()),
                      Text(
                        formatDuration(_weeklyTotal),
                        style: AppTextStyles.mono(color: AppColors.text),
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
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                      child: Text(
                        _isEditing ? 'SAVE CHANGES' : 'CREATE GOAL',
                        style: AppTextStyles.small(color: AppColors.bg),
                      ),
                    ),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: AppSpacing.s2),
                    GestureDetector(
                      onTap: _delete,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 44),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'DELETE GOAL',
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

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime value;
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
            decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
            child: Text(DateFormat('d MMM y').format(value), style: AppTextStyles.label()),
          ),
        ),
      ],
    );
  }
}

/// One weekday's block in the unified schedule: a header row (day label +
/// running total), one row per entry (duration stepper or time-range
/// chips, each with its own remove control), then two small links to add
/// another entry of either kind — so a day can hold a mix, or several of
/// the same kind (a split shift, extra untimed time on top of a shift...).
class _DayScheduleSection extends StatelessWidget {
  const _DayScheduleSection({
    required this.label,
    required this.entries,
    required this.total,
    required this.onAddDuration,
    required this.onAddTimeRange,
    required this.onRemove,
    required this.onStepDuration,
    required this.onEditRangeStart,
    required this.onEditRangeEnd,
  });

  final String label;
  final List<DayScheduleEntry> entries;
  final Duration total;
  final VoidCallback onAddDuration;
  final VoidCallback onAddTimeRange;
  final ValueChanged<int> onRemove;
  final void Function(int index, int deltaMinutes) onStepDuration;
  final ValueChanged<int> onEditRangeStart;
  final ValueChanged<int> onEditRangeEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.mono(color: AppColors.text)),
              Text(
                total == Duration.zero ? 'off' : formatDuration(total),
                style: AppTextStyles.mono(color: AppColors.text),
              ),
            ],
          ),
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: entries[i].isTimeRange
                  ? _EntryTimeRangeRow(
                      range: entries[i].timeRange!,
                      onTapStart: () => onEditRangeStart(i),
                      onTapEnd: () => onEditRangeEnd(i),
                      onRemove: () => onRemove(i),
                    )
                  : _EntryDurationRow(
                      value: entries[i].duration!,
                      onDecrement: () => onStepDuration(i, -_step.inMinutes),
                      onIncrement: () => onStepDuration(i, _step.inMinutes),
                      onRemove: () => onRemove(i),
                    ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                _SmallActionButton(label: '+ duration', onTap: onAddDuration),
                const SizedBox(width: AppSpacing.s2),
                _SmallActionButton(label: '+ time range', onTap: onAddTimeRange),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryDurationRow extends StatelessWidget {
  const _EntryDurationRow({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  final Duration value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        _MiniStepButton(label: '–', onTap: onDecrement),
        SizedBox(
          width: 72,
          child: Text(
            formatDuration(value),
            textAlign: TextAlign.center,
            style: AppTextStyles.mono(color: AppColors.text),
          ),
        ),
        _MiniStepButton(label: '+', onTap: onIncrement),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s2),
          child: _RemoveButton(onTap: onRemove),
        ),
      ],
    );
  }
}

class _EntryTimeRangeRow extends StatelessWidget {
  const _EntryTimeRangeRow({
    required this.range,
    required this.onTapStart,
    required this.onTapEnd,
    required this.onRemove,
  });

  final ClockRange range;
  final VoidCallback onTapStart;
  final VoidCallback onTapEnd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // The time range itself, on the left — the thing you actually set.
        Expanded(child: _ClockChip(label: range.start.format(), onTap: onTapStart)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('–', style: AppTextStyles.mono()),
        ),
        Expanded(child: _ClockChip(label: range.end.format(), onTap: onTapEnd)),
        // What that range comes out to, on the right — derived, not editable
        // here; change the times to change it.
        SizedBox(
          width: 56,
          child: Text(
            formatDuration(range.duration),
            textAlign: TextAlign.right,
            style: AppTextStyles.mono(color: AppColors.text),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s2),
          child: _RemoveButton(onTap: onRemove),
        ),
      ],
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
        child: Text(label, style: AppTextStyles.mono(color: AppColors.text)),
      ),
    );
  }
}

class _MiniStepButton extends StatelessWidget {
  const _MiniStepButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: AppColors.text)),
        child: Text(label, style: AppTextStyles.label()),
      ),
    );
  }
}

/// A small bordered action — "+ duration", "+ time range", "same every
/// day" — flat with a soft 30%-ink border, same visual language as an
/// unselected [CategoryChip], so these read clearly as buttons rather than
/// plain inline text, with a real tap target rather than just the glyph's
/// own bounding box.
class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
        decoration: BoxDecoration(border: Border.all(color: AppColors.ink(0.3))),
        child: Text(label, style: AppTextStyles.mono(color: AppColors.accent)),
      ),
    );
  }
}

/// A schedule entry's remove control — a small bordered square, same
/// footprint family as [_MiniStepButton]/[_ClockChip], so it reads as a
/// deliberate button next to them instead of a stray glyph.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: AppColors.ink(0.3))),
        child: Text('×', style: AppTextStyles.mono(color: AppColors.accent)),
      ),
    );
  }
}
