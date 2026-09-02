import 'package:flutter/material.dart'
    show TimeOfDay, showModalBottomSheet, showTimePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/clock_time.dart';
import '../../models/user_settings.dart';
import '../../shared/widgets/confirm_delete_dialog.dart';
import '../../shared/widgets/inline_form_error.dart';
import '../../state/user_settings_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/duration_format.dart';

/// Which hours of each weekday count as "trackable" — feeds the Capacity
/// page's planned-vs-available breakdown and the Day view's "untracked"
/// gap detection. Each day can hold more than one range (e.g. an early
/// shift and a late one, skipping a midday gap); a day left at its default
/// tracks the full 24 hours.
Future<void> showTrackingWindowSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    // Same reasoning as the goal-edit and add-block sheets: enableDrag
    // stays off so a swipe-to-dismiss can't bypass the unsaved-changes
    // prompt below via BottomSheet's own onClosing path.
    enableDrag: false,
    builder: (context) => _TrackingWindowSheet(ref: ref),
  );
}

class _TrackingWindowSheet extends StatefulWidget {
  const _TrackingWindowSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_TrackingWindowSheet> createState() => _TrackingWindowSheetState();
}

class _TrackingWindowSheetState extends State<_TrackingWindowSheet> {
  // Seeded from the live settings' own windowsForWeekday, so every weekday
  // starts with an explicit, editable list — including the ones with no
  // saved entry of their own, which would otherwise silently default to
  // [fullDayWindow] with nothing on screen to show or change that.
  late final Map<int, List<ClockRange>> _windows = {
    for (var weekday = 1; weekday <= 7; weekday++)
      weekday: List.of(
        widget.ref.read(userSettingsProvider).windowsForWeekday(weekday),
      ),
  };

  // Captured eagerly in initState (via the field initializer above running
  // before build), not lazily — see the same note on add_block_sheet's own
  // `_initialSnapshot` for why a lazy `late` here would be a real bug.
  late final Map<int, List<ClockRange>> _initialSnapshot = {
    for (final entry in _windows.entries) entry.key: List.of(entry.value),
  };

  // Shown inline rather than as a SnackBar — see InlineFormError's own doc
  // comment for why a SnackBar doesn't work while this sheet is open. A
  // real, not hypothetical, failure mode: this exact save silently did
  // nothing the first time it shipped, because the Firestore write threw
  // (rules not yet deployed for the new collection) and nothing caught it
  // — the sheet just sat there looking like the tap had no effect.
  String? _errorMessage;
  bool _saving = false;

  bool get _hasUnsavedChanges {
    for (var weekday = 1; weekday <= 7; weekday++) {
      final current = _windows[weekday]!;
      final initial = _initialSnapshot[weekday]!;
      if (current.length != initial.length) return true;
      for (var i = 0; i < current.length; i++) {
        if (current[i].start.minutesSinceMidnight !=
                initial[i].start.minutesSinceMidnight ||
            current[i].end.minutesSinceMidnight !=
                initial[i].end.minutesSinceMidnight) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _handleClose() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final shouldSave = await showConfirmDialog(
      context,
      title: 'Save changes?',
      message: 'You have unsaved changes to your tracking window.',
      confirmLabel: 'Save',
    );
    if (!mounted) return;
    if (shouldSave) {
      await _save();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await saveUserSettings(
        widget.ref,
        UserSettings(
          trackingWindowsByWeekday: _windows,
          defaultOpenHour: widget.ref.read(userSettingsProvider).defaultOpenHour,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              "Couldn't save — check your connection and try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addRange(int weekday) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (start == null || !mounted) return;
    // Suggest an hour after the start just picked, rather than a fixed
    // clock time unrelated to it.
    final suggestedEnd = TimeOfDay(
      hour: (start.hour + 1) % 24,
      minute: start.minute,
    );
    final end = await showTimePicker(
      context: context,
      initialTime: suggestedEnd,
    );
    if (end == null || !mounted) return;
    setState(() {
      _windows[weekday]!.add(
        ClockRange(
          ClockTime(start.hour, start.minute),
          ClockTime(end.hour, end.minute),
        ),
      );
    });
  }

  void _removeRange(int weekday, int index) {
    setState(() => _windows[weekday]!.removeAt(index));
  }

  Future<void> _editRangeStart(int weekday, int index) async {
    final current = _windows[weekday]![index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.start.hour,
        minute: current.start.minute,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _windows[weekday]![index] = ClockRange(
        ClockTime(picked.hour, picked.minute),
        current.end,
      );
    });
  }

  Future<void> _editRangeEnd(int weekday, int index) async {
    final current = _windows[weekday]![index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.end.hour,
        minute: current.end.minute,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _windows[weekday]![index] = ClockRange(
        current.start,
        ClockTime(picked.hour, picked.minute),
      );
    });
  }

  void _setFullDay(int weekday) {
    setState(() => _windows[weekday] = [fullDayWindow]);
  }

  void _applySameEveryDay() {
    setState(() {
      final monday = List.of(_windows[DateTime.monday]!);
      for (var weekday = 1; weekday <= 7; weekday++) {
        _windows[weekday] = List.of(monday);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
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
                        Text('Tracking window', style: AppTextStyles.title()),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _saving ? null : _handleClose,
                              behavior: HitTestBehavior.opaque,
                              child: Text(
                                'close',
                                style: AppTextStyles.mono(),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s3),
                            GestureDetector(
                              onTap: _saving ? null : _save,
                              behavior: HitTestBehavior.opaque,
                              child: Text(
                                _saving ? 'saving…' : 'save',
                                style: AppTextStyles.mono(
                                  color: AppColors.accent,
                                ),
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
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'which hours of each day count as trackable — feeds '
                      'the Capacity page and "untracked" gaps on the Day '
                      'view',
                      style: AppTextStyles.mono(),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _SmallLink(
                        label: 'same every day',
                        onTap: _applySameEveryDay,
                      ),
                    ),
                    for (var weekday = 1; weekday <= 7; weekday++)
                      _WeekdaySection(
                        // 1 Jan 2024 was a Monday, so offsetting from it by
                        // (weekday - 1) days lands on the right weekday
                        // name without a manual weekday->name lookup table.
                        label: DateFormat(
                          'EEEE',
                        ).format(DateTime(2024, 1, weekday)),
                        ranges: _windows[weekday]!,
                        onAddRange: () => _addRange(weekday),
                        onSetFullDay: () => _setFullDay(weekday),
                        onRemove: (i) => _removeRange(weekday, i),
                        onEditStart: (i) => _editRangeStart(weekday, i),
                        onEditEnd: (i) => _editRangeEnd(weekday, i),
                      ),
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

class _WeekdaySection extends StatelessWidget {
  const _WeekdaySection({
    required this.label,
    required this.ranges,
    required this.onAddRange,
    required this.onSetFullDay,
    required this.onRemove,
    required this.onEditStart,
    required this.onEditEnd,
  });

  final String label;
  final List<ClockRange> ranges;
  final VoidCallback onAddRange;
  final VoidCallback onSetFullDay;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onEditStart;
  final ValueChanged<int> onEditEnd;

  bool get _isFullDay =>
      ranges.length == 1 &&
      ranges.single.start.minutesSinceMidnight == 0 &&
      ranges.single.end.minutesSinceMidnight == fullDayWindow.end.minutesSinceMidnight;

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
                _isFullDay ? '24h' : (ranges.isEmpty ? 'off' : ''),
                style: AppTextStyles.mono(color: AppColors.text),
              ),
            ],
          ),
          for (var i = 0; i < ranges.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _RangeRow(
                range: ranges[i],
                onTapStart: () => onEditStart(i),
                onTapEnd: () => onEditEnd(i),
                onRemove: () => onRemove(i),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                _SmallLink(label: '+ range', onTap: onAddRange),
                const SizedBox(width: AppSpacing.s2),
                if (!_isFullDay)
                  _SmallLink(label: '24 hours', onTap: onSetFullDay),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({
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
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neutral500),
          borderRadius: AppShapes.small,
        ),
        child: Text(label, style: AppTextStyles.mono(color: AppColors.text)),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Text('×', style: AppTextStyles.mono(color: AppColors.accent)),
        ),
      ),
    );
  }
}

class _SmallLink extends StatelessWidget {
  const _SmallLink({required this.label, required this.onTap});

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
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neutral500),
          borderRadius: AppShapes.small,
        ),
        child: Text(label, style: AppTextStyles.small(color: AppColors.text)),
      ),
    );
  }
}
