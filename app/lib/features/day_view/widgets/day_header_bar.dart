import 'package:flutter/material.dart'
    show PopupMenuButton, PopupMenuDivider, PopupMenuItem, showDatePicker;
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
import 'live_activity_button.dart';

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
            _OverflowMenuButton(
              mode: mode,
              onModeChanged: (value) =>
                  ref.read(dayViewModeProvider.notifier).state = value,
              filter: ref.watch(dayViewBlockFilterProvider),
              onFilterChanged: (value) =>
                  ref.read(dayViewBlockFilterProvider.notifier).state = value,
              fullDay: ref.watch(dayViewFullDayProvider),
              onFullDayChanged: (value) =>
                  ref.read(dayViewFullDayProvider.notifier).state = value,
            ),
            const SizedBox(width: AppSpacing.s2),
            const LiveActivityButton(),
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

/// Wraps a callback so [PopupMenuButton] can carry three different action
/// shapes (pick a view mode, pick a filter, toggle full-day) through one
/// `onSelected`, without a combined enum every unrelated caller has to
/// pattern-match through.
class _MenuChoice {
  const _MenuChoice(this.onSelect);

  final VoidCallback onSelect;
}

/// One bordered "⋮" button opening every other header control that isn't
/// date navigation or the two primary actions (Start, + Log) — the view
/// mode, the Plan/Registered filter, and the full-day toggle, previously
/// three separate buttons crowding this header on top of those. A single
/// entry point, sectioned by [_MenuSectionHeader], each still a one-tap
/// selection that closes the menu — same interaction each control already
/// had on its own.
class _OverflowMenuButton extends StatelessWidget {
  const _OverflowMenuButton({
    required this.mode,
    required this.onModeChanged,
    required this.filter,
    required this.onFilterChanged,
    required this.fullDay,
    required this.onFullDayChanged,
  });

  final DayViewMode mode;
  final ValueChanged<DayViewMode> onModeChanged;
  final DayViewBlockFilter filter;
  final ValueChanged<DayViewBlockFilter> onFilterChanged;
  final bool fullDay;
  final ValueChanged<bool> onFullDayChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuChoice>(
      onSelected: (choice) => choice.onSelect(),
      color: AppColors.surface,
      elevation: 8,
      padding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
      itemBuilder: (context) => [
        const PopupMenuItem<_MenuChoice>(
          enabled: false,
          padding: EdgeInsets.zero,
          height: 28,
          child: _MenuSectionHeader('VIEW'),
        ),
        for (final option in _viewModeOptions)
          PopupMenuItem<_MenuChoice>(
            value: _MenuChoice(() => onModeChanged(option.value)),
            padding: EdgeInsets.zero,
            height: 40,
            child: _MenuRow(label: option.label, selected: option.value == mode),
          ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<_MenuChoice>(
          enabled: false,
          padding: EdgeInsets.zero,
          height: 28,
          child: _MenuSectionHeader('SHOW'),
        ),
        for (final option in _blockFilterOptions)
          PopupMenuItem<_MenuChoice>(
            value: _MenuChoice(() => onFilterChanged(option.value)),
            padding: EdgeInsets.zero,
            height: 40,
            child: _MenuRow(label: option.label, selected: option.value == filter),
          ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<_MenuChoice>(
          value: _MenuChoice(() => onFullDayChanged(!fullDay)),
          padding: EdgeInsets.zero,
          height: 40,
          child: _MenuRow(label: 'Full day (24h)', selected: fullDay),
        ),
      ],
      child: Container(
        // No `alignment` here — Container treats a non-null alignment as
        // "expand to fill the incoming bounded constraint, then align the
        // child within it," which under the header's stretched Column
        // silently turned this into a full-width button. mainAxisSize.min
        // on the Row below already keeps this hugging its own content.
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.neutral500),
          borderRadius: AppShapes.small,
        ),
        child: Text('⋮', style: AppTextStyles.label(color: AppColors.text)),
      ),
    );
  }
}

class _MenuSectionHeader extends StatelessWidget {
  const _MenuSectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      child: Text(text, style: AppTextStyles.kicker()),
    );
  }
}

/// One selectable row inside the overflow menu — a checkmark when
/// [selected], matching how a real menu (not a segmented control) shows
/// the current choice among several, rather than this app's usual
/// highlighted-background convention which doesn't read as clearly at
/// this row height.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      color: selected ? AppColors.accent100 : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.label(
                color: selected ? AppColors.accent : null,
              ).copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (selected)
            Text('✓', style: AppTextStyles.label(color: AppColors.accent)),
        ],
      ),
    );
  }
}
