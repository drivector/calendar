import 'package:flutter/material.dart'
    show PopupMenuButton, PopupMenuItem, showDatePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/step_arrow_button.dart';
import '../../../state/day_view_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Expanded, not a bare Row: it claims the leftover width so the
            // mode button and "+ Log" are pushed flush right, and it lets
            // the date block shrink. That shrinking matters — a long
            // kicker ("WORKING WEEK") beside a long mode label is exactly
            // the combination that overflowed a real phone width before,
            // and now it ellipsizes instead.
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StepArrowButton(
                    direction: StepDirection.previous,
                    onTap: () => stepDayViewWindow(ref, forward: false),
                  ),
                  Flexible(
                    child: GestureDetector(
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            mode == DayViewMode.day
                                ? DateFormat('d MMM').format(selectedDate)
                                : _rangeLabel(visibleDates),
                            style: AppTextStyles.title(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  StepArrowButton(
                    direction: StepDirection.next,
                    onTap: () => stepDayViewWindow(ref, forward: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            _ViewModeButton(
              mode: mode,
              onChanged: (value) =>
                  ref.read(dayViewModeProvider.notifier).state = value,
            ),
            const SizedBox(width: AppSpacing.s2),
            _BlockFilterButton(
              filter: ref.watch(dayViewBlockFilterProvider),
              onChanged: (value) =>
                  ref.read(dayViewBlockFilterProvider.notifier).state = value,
            ),
            const SizedBox(width: AppSpacing.s2),
            _FullDayToggle(
              active: ref.watch(dayViewFullDayProvider),
              onTap: () => ref.read(dayViewFullDayProvider.notifier).state =
                  !ref.read(dayViewFullDayProvider),
            ),
            const SizedBox(width: AppSpacing.s2),
            GestureDetector(
              onTap: () => showLogActivitySheet(context, ref),
              behavior: HitTestBehavior.opaque,
              child: Container(
                constraints: const BoxConstraints(minHeight: 32),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
                // The one primary action on this screen — Fluent gives
                // exactly one filled brand button per surface and leaves
                // everything else neutral.
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: AppShapes.small,
                ),
                child: Text(
                  '+ Log',
                  style: AppTextStyles.small(color: AppColors.surface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggles [dayViewFullDayProvider] — compressing the whole 24 hours into
/// the visible height (no scrolling) versus the normal fixed-scale,
/// scrollable timeline. Bordered, not filled — "+ Log" is already this
/// screen's one filled accent button.
class _FullDayToggle extends StatelessWidget {
  const _FullDayToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
        decoration: BoxDecoration(
          color: active ? AppColors.accent100 : AppColors.surface,
          border: Border.all(
            color: active ? AppColors.accent : AppColors.neutral500,
          ),
          borderRadius: AppShapes.small,
        ),
        child: Text(
          '24h',
          style: AppTextStyles.small(
            color: active ? AppColors.accent : AppColors.text,
          ),
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

const _viewModeOptions = [
  (value: DayViewMode.day, label: 'Day'),
  (value: DayViewMode.threeDay, label: '3 Day'),
  (value: DayViewMode.workingWeek, label: 'Working week'),
  (value: DayViewMode.week, label: 'Week'),
];

const _blockFilterOptions = [
  (value: DayViewBlockFilter.both, label: 'All'),
  (value: DayViewBlockFilter.plannedOnly, label: 'Planned'),
  (value: DayViewBlockFilter.registeredOnly, label: 'Registered'),
];

/// A single bordered button showing the active view range, opening a
/// dropdown menu of the other options on tap — the same "one button, tap
/// for a menu" pattern a calendar app's own view switcher uses, replacing
/// the previous 4-option segmented control (which fit in tests but
/// overflowed a real phone's width).
class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({required this.mode, required this.onChanged});

  final DayViewMode mode;
  final ValueChanged<DayViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final currentLabel = _viewModeOptions
        .firstWhere((option) => option.value == mode)
        .label;

    return PopupMenuButton<DayViewMode>(
      initialValue: mode,
      onSelected: onChanged,
      color: AppColors.surface,
      // A real flyout now — Fluent floats menus above the page with
      // shadow8 rather than pinning them flat against it.
      elevation: 8,
      padding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
      itemBuilder: (context) => [
        for (final option in _viewModeOptions)
          PopupMenuItem<DayViewMode>(
            value: option.value,
            padding: EdgeInsets.zero,
            height: 40,
            child: Container(
              width: double.infinity,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
              color: option.value == mode ? AppColors.accent100 : null,
              child: Text(
                option.label,
                style: AppTextStyles.label(
                  color: option.value == mode ? AppColors.accent : null,
                ).copyWith(
                  fontWeight: option.value == mode
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
      ],
      child: Container(
        // No `alignment` here — Container treats a non-null alignment as
        // "expand to fill the incoming bounded constraint, then align the
        // child within it," which under the header's stretched Column
        // silently turned this into a full-width button. mainAxisSize.min
        // on the Row below already keeps this hugging its own content.
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2,
          vertical: AppSpacing.s1,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.neutral500),
          borderRadius: AppShapes.small,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(currentLabel, style: AppTextStyles.small(color: AppColors.text)),
            const SizedBox(width: 4),
            Text('▾', style: AppTextStyles.small(color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}

/// Same "one bordered button, tap for a menu" pattern as [_ViewModeButton]
/// — filters which of Plan/Actual the timeline below actually draws (see
/// [DayViewBlockFilter]'s own doc comment for what it does and doesn't
/// affect).
class _BlockFilterButton extends StatelessWidget {
  const _BlockFilterButton({required this.filter, required this.onChanged});

  final DayViewBlockFilter filter;
  final ValueChanged<DayViewBlockFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final currentLabel = _blockFilterOptions
        .firstWhere((option) => option.value == filter)
        .label;

    return PopupMenuButton<DayViewBlockFilter>(
      initialValue: filter,
      onSelected: onChanged,
      color: AppColors.surface,
      elevation: 8,
      padding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
      itemBuilder: (context) => [
        for (final option in _blockFilterOptions)
          PopupMenuItem<DayViewBlockFilter>(
            value: option.value,
            padding: EdgeInsets.zero,
            height: 40,
            child: Container(
              width: double.infinity,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
              color: option.value == filter ? AppColors.accent100 : null,
              child: Text(
                option.label,
                style: AppTextStyles.label(
                  color: option.value == filter ? AppColors.accent : null,
                ).copyWith(
                  fontWeight: option.value == filter
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2,
          vertical: AppSpacing.s1,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.neutral500),
          borderRadius: AppShapes.small,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(currentLabel, style: AppTextStyles.small(color: AppColors.text)),
            const SizedBox(width: 4),
            Text('▾', style: AppTextStyles.small(color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}
