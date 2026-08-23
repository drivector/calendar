import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/clock_time.dart';
import '../../../models/goal.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../shared/widgets/segmented_control.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _step = Duration(minutes: 5);
const _maxPerDay = Duration(hours: 8);
const _defaultRangeStart = TimeOfDay(hour: 9, minute: 0);
const _defaultRangeEnd = TimeOfDay(hour: 17, minute: 0);

Map<int, Duration> _defaultTargets() => {
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: const Duration(minutes: 30),
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
  late GoalScheduleMode _scheduleMode =
      widget.existing?.scheduleMode ?? GoalScheduleMode.duration;
  late final Map<int, Duration> _targets =
      Map.of(widget.existing?.targetsByWeekday ?? _defaultTargets());
  late final Map<int, ClockRange> _timeRanges =
      Map.of(widget.existing?.timeRangesByWeekday ?? {});

  bool get _isEditing => widget.existing != null;

  Duration get _weeklyTotal => _scheduleMode == GoalScheduleMode.duration
      ? _targets.values.fold(Duration.zero, (a, b) => a + b)
      : _timeRanges.values.fold(Duration.zero, (a, r) => a + r.duration);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _stepTarget(int weekday, int deltaMinutes) {
    setState(() {
      final current = _targets[weekday] ?? Duration.zero;
      final next = current + Duration(minutes: deltaMinutes);
      _targets[weekday] = next < Duration.zero
          ? Duration.zero
          : (next > _maxPerDay ? _maxPerDay : next);
    });
  }

  void _applySameEveryDay() {
    setState(() {
      if (_scheduleMode == GoalScheduleMode.duration) {
        final mondayValue = _targets[DateTime.monday] ?? Duration.zero;
        for (var weekday = 1; weekday <= 7; weekday++) {
          _targets[weekday] = mondayValue;
        }
      } else {
        final mondayRange = _timeRanges[DateTime.monday];
        for (var weekday = 1; weekday <= 7; weekday++) {
          if (mondayRange == null) {
            _timeRanges.remove(weekday);
          } else {
            _timeRanges[weekday] = mondayRange;
          }
        }
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

  Future<void> _enableTimeRange(int weekday) async {
    final start = await showTimePicker(context: context, initialTime: _defaultRangeStart);
    if (start == null || !mounted) return;
    final end = await showTimePicker(context: context, initialTime: _defaultRangeEnd);
    if (end == null) return;
    setState(() {
      _timeRanges[weekday] = ClockRange(
        ClockTime(start.hour, start.minute),
        ClockTime(end.hour, end.minute),
      );
    });
  }

  Future<void> _editRangeStart(int weekday) async {
    final current = _timeRanges[weekday];
    if (current == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.start.hour, minute: current.start.minute),
    );
    if (picked == null) return;
    setState(() {
      _timeRanges[weekday] = ClockRange(ClockTime(picked.hour, picked.minute), current.end);
    });
  }

  Future<void> _editRangeEnd(int weekday) async {
    final current = _timeRanges[weekday];
    if (current == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.end.hour, minute: current.end.minute),
    );
    if (picked == null) return;
    setState(() {
      _timeRanges[weekday] = ClockRange(current.start, ClockTime(picked.hour, picked.minute));
    });
  }

  void _clearTimeRange(int weekday) => setState(() => _timeRanges.remove(weekday));

  void _save() {
    final targets = _scheduleMode == GoalScheduleMode.duration
        ? Map.of(_targets)
        : {for (final entry in _timeRanges.entries) entry.key: entry.value.duration};

    final goal = Goal(
      id: widget.existing?.id ?? 'goal-${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty
          ? 'Untitled goal'
          : _nameController.text.trim(),
      categoryId: _categoryId,
      type: _type,
      targetsByWeekday: targets,
      startDate: _startDate,
      endDate: _endDate,
      scheduleMode: _scheduleMode,
      timeRangesByWeekday:
          _scheduleMode == GoalScheduleMode.timeRange ? Map.of(_timeRanges) : null,
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
                  _Label('Schedule by'),
                  SegmentedControl<GoalScheduleMode>(
                    selected: _scheduleMode,
                    onChanged: (value) => setState(() => _scheduleMode = value),
                    options: const [
                      SegmentedOption(value: GoalScheduleMode.duration, label: 'Duration'),
                      SegmentedOption(value: GoalScheduleMode.timeRange, label: 'Time range'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Label(_scheduleMode == GoalScheduleMode.duration
                          ? 'Daily targets'
                          : 'Daily time range'),
                      GestureDetector(
                        onTap: _applySameEveryDay,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            'same every day',
                            style: AppTextStyles.mono(color: AppColors.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_scheduleMode == GoalScheduleMode.duration)
                    for (var weekday = 1; weekday <= 7; weekday++)
                      _WeekdayTargetRow(
                        label: _weekdayLabels[weekday - 1],
                        value: _targets[weekday] ?? Duration.zero,
                        onDecrement: () => _stepTarget(weekday, -_step.inMinutes),
                        onIncrement: () => _stepTarget(weekday, _step.inMinutes),
                      )
                  else
                    for (var weekday = 1; weekday <= 7; weekday++)
                      _WeekdayTimeRangeRow(
                        label: _weekdayLabels[weekday - 1],
                        range: _timeRanges[weekday],
                        onEnable: () => _enableTimeRange(weekday),
                        onTapStart: () => _editRangeStart(weekday),
                        onTapEnd: () => _editRangeEnd(weekday),
                        onClear: () => _clearTimeRange(weekday),
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

class _WeekdayTargetRow extends StatelessWidget {
  const _WeekdayTargetRow({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final Duration value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text(label, style: AppTextStyles.mono())),
          const Spacer(),
          _MiniStepButton(label: '–', onTap: onDecrement),
          SizedBox(
            width: 72,
            child: Text(
              value == Duration.zero ? 'off' : formatDuration(value),
              textAlign: TextAlign.center,
              style: AppTextStyles.mono(color: AppColors.text),
            ),
          ),
          _MiniStepButton(label: '+', onTap: onIncrement),
        ],
      ),
    );
  }
}

class _WeekdayTimeRangeRow extends StatelessWidget {
  const _WeekdayTimeRangeRow({
    required this.label,
    required this.range,
    required this.onEnable,
    required this.onTapStart,
    required this.onTapEnd,
    required this.onClear,
  });

  final String label;
  final ClockRange? range;
  final VoidCallback onEnable;
  final VoidCallback onTapStart;
  final VoidCallback onTapEnd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final range = this.range;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text(label, style: AppTextStyles.mono())),
          const SizedBox(width: AppSpacing.s2),
          if (range == null)
            Expanded(
              child: GestureDetector(
                onTap: onEnable,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  alignment: Alignment.centerLeft,
                  child: Text('off — tap to set', style: AppTextStyles.mono()),
                ),
              ),
            )
          else ...[
            Expanded(
              child: _ClockChip(label: range.start.format(), onTap: onTapStart),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('–', style: AppTextStyles.mono()),
            ),
            Expanded(
              child: _ClockChip(label: range.end.format(), onTap: onTapEnd),
            ),
            GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s2),
                child: Text('×', style: AppTextStyles.mono(color: AppColors.accent)),
              ),
            ),
          ],
        ],
      ),
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
