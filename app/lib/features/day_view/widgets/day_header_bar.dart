import 'package:flutter/material.dart' show showDatePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/segmented_control.dart';
import '../../../shared/widgets/step_arrow_button.dart';
import '../../../state/day_view_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../log_activity/widgets/log_activity_sheet.dart';

class DayHeaderBar extends ConsumerWidget {
  const DayHeaderBar({super.key});

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: ref.read(selectedDateProvider),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(selectedDateProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final mode = ref.watch(dayViewModeProvider);
    final visibleDates = ref.watch(visibleDatesProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.text, width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StepArrowButton(
                      direction: StepDirection.previous,
                      onTap: () => stepDayViewWindow(ref, forward: false),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    GestureDetector(
                      onTap: () => _pickDate(context, ref),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mode == DayViewMode.day
                                ? DateFormat(
                                    'EEEE',
                                  ).format(selectedDate).toUpperCase()
                                : _kickerFor(mode),
                            style: AppTextStyles.kicker(),
                          ),
                          Text(
                            mode == DayViewMode.day
                                ? DateFormat('d MMM').format(selectedDate)
                                : _rangeLabel(visibleDates),
                            style: AppTextStyles.title(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    StepArrowButton(
                      direction: StepDirection.next,
                      onTap: () => stepDayViewWindow(ref, forward: true),
                    ),
                  ],
                ),
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
            const SizedBox(height: AppSpacing.s2),
            // Its own row, full width — "Day | 3 Day | Working week | Week"
            // alongside the arrows/date/+LOG row above overflowed on a real
            // phone width (only fit in tests, whose default viewport is far
            // wider than any phone).
            SegmentedControl<DayViewMode>(
              selected: mode,
              stretch: true,
              onChanged: (value) =>
                  ref.read(dayViewModeProvider.notifier).state = value,
              options: const [
                SegmentedOption(value: DayViewMode.day, label: 'Day'),
                SegmentedOption(value: DayViewMode.threeDay, label: '3 Day'),
                SegmentedOption(
                  value: DayViewMode.workingWeek,
                  label: 'Working week',
                ),
                SegmentedOption(value: DayViewMode.week, label: 'Week'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _kickerFor(DayViewMode mode) => switch (mode) {
  DayViewMode.day => 'DAY',
  DayViewMode.threeDay => '3 DAY',
  DayViewMode.workingWeek => 'WORKING WEEK',
  DayViewMode.week => 'WEEK',
};

/// "24 – 30 Aug" — the same range format the old Week tab used.
String _rangeLabel(List<DateTime> visibleDates) {
  final first = visibleDates.first;
  final last = visibleDates.last;
  return '${DateFormat('d').format(first)} – ${DateFormat('d MMM').format(last)}';
}
