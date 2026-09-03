import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/tracked_block.dart';
import '../../../models/user_settings.dart';
import '../../../shared/widgets/date_swipe_nav.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../state/running_activity_providers.dart';
import '../../../state/user_settings_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'actual_block_widget.dart';
import 'add_block_sheet.dart';
import 'block_label_style.dart';
import 'live_activity_running_block.dart';
import 'plan_block_widget.dart';

/// Left gutter reserved for the hour labels ("06", "07", ...).
const kGutterWidth = 38.0;

/// How far an actual block's own left edge sits from its day-column's left
/// edge, as a fraction of the column's width — planned blocks still span
/// the full column, so this sliver is what keeps a planned block visible
/// (not fully covered) when an actual block overlaps it in time.
const _actualBlockInset = 0.1;


/// One day-column's horizontal slot within the timeline — shared by
/// [TimeBodyGrid] and the per-column date-label header above it so the two
/// can never drift out of pixel alignment with each other.
class DayColumnLayout {
  const DayColumnLayout({required this.left, required this.width});

  final double left;
  final double width;
}

List<DayColumnLayout> columnLayoutsFor(double totalWidth, int columnCount) {
  final columnWidth = (totalWidth - kGutterWidth) / columnCount;
  return List.generate(
    columnCount,
    (i) => DayColumnLayout(left: kGutterWidth + i * columnWidth, width: columnWidth),
  );
}

/// A continuous, scrollable 24-hour timeline showing 1, 3, 5, or 7 day
/// columns side by side (see [DayViewMode]) — hour rows at a fixed height,
/// events positioned and sized by their real clock time, the way a standard
/// calendar app's day/week view works (Google/Apple Calendar), rather than
/// one row per planned block. Within each column, Plan and Actual share a
/// single slot (not side-by-side lanes) so a planned block and what
/// actually happened for it sit directly on top of one another — planned
/// blocks stay a dashed, unfilled outline (painted first) specifically so a
/// solid Actual block (painted after, and the only one of the two with its
/// own tap handler) reads clearly on top of it rather than the two
/// competing for the same space. Tapping empty space — including an
/// untracked gap, which has no widget of its own — opens [showAddBlockSheet]
/// to log a new actual entry for that column's own date; tapping an
/// existing block opens its own sheet instead, since it's painted on top
/// and claims the hit first.
///
/// Wrapped by the caller in an [Expanded]/[Flexible] — this widget must not
/// introduce its own [Expanded] (two [Expanded]s cannot share one underlying
/// render object).
class TimeBodyGrid extends ConsumerStatefulWidget {
  const TimeBodyGrid({super.key});

  @override
  ConsumerState<TimeBodyGrid> createState() => _TimeBodyGridState();
}

/// 72px/hour — dense enough to fit a full day on screen with modest
/// scrolling, generous enough that a 30-minute block still reads clearly.
/// Used as-is in the normal scrollable mode; in full-day mode (see
/// [dayViewFullDayProvider]) the scale shrinks instead to fit the whole 24
/// hours in the available height with no scrolling at all.
const _defaultPxPerMinute = 1.2;

class _TimeBodyGridState extends ConsumerState<TimeBodyGrid> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _initialScrollOffset,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Anchored to the user's configured default open hour (Account >
  // Details, defaults to 18:00) — the same anchor in every view mode, so
  // entering the Calendar tab (or changing date/mode) always lands there
  // rather than wherever the day's own first event happens to be. Only
  // meaningful in the normal scrollable mode — full-day mode never
  // scrolls, so this value is simply unused there.
  double get _initialScrollOffset =>
      ref.read(userSettingsProvider).defaultOpenHour * 60 * _defaultPxPerMinute;

  // Logs an actual entry for a past or ongoing slot — with Plan and Actual
  // sharing one slot, there's no separate Plan-only region to tap for a
  // manual planned block otherwise. A tap on a slot that hasn't happened
  // yet opens as a plan instead: logging something as already done before
  // it's even occurred doesn't make sense, and it saves a trip to a goal's
  // schedule just to pencil in a one-off future activity.
  void _handleEmptySpaceTap(
    TapUpDetails details,
    DateTime date,
    double pxPerMinute,
  ) {
    final minutes = (details.localPosition.dy / pxPerMinute).round();
    final rounded = ((minutes / 15).round() * 15).clamp(0, 24 * 60 - 30);
    final tappedTime = DateTime(
      date.year,
      date.month,
      date.day,
      rounded ~/ 60,
      rounded % 60,
    );
    showAddBlockSheet(
      context,
      ref,
      isPlan: tappedTime.isAfter(DateTime.now()),
      date: date,
      initialStart: TimeOfDay(hour: rounded ~/ 60, minute: rounded % 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Changing the selected date or the view mode re-centers the timeline
    // on the (Day-mode-only) first event, or the fixed default otherwise.
    ref.listen<DateTime>(selectedDateProvider, (previous, next) {
      if (previous == next) return;
      _jumpToInitialOffset();
    });
    ref.listen<DayViewMode>(dayViewModeProvider, (previous, next) {
      if (previous == next) return;
      _jumpToInitialOffset();
    });
    ref.listen<UserSettings>(userSettingsProvider, (previous, next) {
      if (previous?.defaultOpenHour == next.defaultOpenHour) return;
      _jumpToInitialOffset();
    });
    // Switching back out of full-day mode leaves the scroll position
    // wherever it happened to be while full-day (usually 0, since nothing
    // scrolls there) — re-center on the default hour like a fresh entry.
    ref.listen<bool>(dayViewFullDayProvider, (previous, next) {
      if (previous == next || next) return;
      _jumpToInitialOffset();
    });

    final dates = ref.watch(visibleDatesProvider);
    final dayBlocks = ref.watch(visibleDayBlocksProvider);
    final categories = ref.watch(categoriesProvider);
    final goals = ref.watch(goalsProvider);
    final fullDay = ref.watch(dayViewFullDayProvider);
    final blockFilter = ref.watch(dayViewBlockFilterProvider);
    final running = ref.watch(runningActivityProvider);
    // Forces this whole grid to rebuild once a second while something's
    // running, so the live block below actually grows over time instead
    // of freezing at whatever height it had when this widget first built
    // — see liveActivityTickProvider's own doc comment. A no-op (no
    // rebuilds at all) whenever nothing is running.
    ref.watch(liveActivityTickProvider);

    return DateSwipeNav(
      onPrevious: () => stepDayViewWindow(ref, forward: false),
      onNext: () => stepDayViewWindow(ref, forward: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layouts = columnLayoutsFor(constraints.maxWidth, dates.length);
          // 25 hours fill the available height either way — one hour past
          // midnight, so a full-day glance (no scrolling) and the normal
          // scrollable mode both leave a sliver of the next day visible
          // instead of stopping dead at the 00 line. Full day just shrinks
          // the scale to fit those 25 hours in the available height instead
          // of using the fixed per-minute scale.
          final pxPerMinute = fullDay
              ? constraints.maxHeight / (25 * 60)
              : _defaultPxPerMinute;
          final dayHeight = fullDay
              ? constraints.maxHeight
              : 25 * 60 * pxPerMinute;

          return SingleChildScrollView(
            controller: _scrollController,
            physics: fullDay ? const NeverScrollableScrollPhysics() : null,
            child: SizedBox(
              height: dayHeight,
              width: double.infinity,
              child: Stack(
                children: [
                  // Full day draws all the way through the "01" line, so
                  // the sliver of the next day it leaves visible actually
                  // reads as one — the normal scrollable mode leaves the
                  // same sliver of room below "00" but without a label on
                  // it, since it's reached by scrolling rather than seen
                  // all at once.
                  for (var hour = 0; hour <= (fullDay ? 25 : 24); hour++)
                    _HourGridLine(
                      hour: hour,
                      gutterWidth: kGutterWidth,
                      hourHeight: 60 * pxPerMinute,
                    ),
                  // A hairline between adjacent day-columns — only when
                  // there's more than one to tell apart (3 Day/Working
                  // week/Week); Day mode has just the one column, nothing
                  // to divide.
                  if (dates.length > 1)
                    for (var i = 1; i < dates.length; i++)
                      Positioned(
                        left: layouts[i].left,
                        top: 0,
                        width: 1,
                        height: dayHeight,
                        child: IgnorePointer(
                          child: ColoredBox(color: AppColors.divider),
                        ),
                      ),
                  for (var i = 0; i < dates.length; i++) ...[
                    // Empty-space tap target — added before the blocks
                    // below so any block painted on top claims its own tap
                    // first.
                    Positioned(
                      left: layouts[i].left,
                      top: 0,
                      width: layouts[i].width,
                      height: dayHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) =>
                            _handleEmptySpaceTap(details, dates[i], pxPerMinute),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // Planned blocks paint first (dashed, unfilled) so a
                    // solid Actual block for the same time reads clearly on
                    // top of it rather than the two competing visually.
                    // Hidden outright when the header's filter is set to
                    // "Registered only" — see [DayViewBlockFilter].
                    if (blockFilter != DayViewBlockFilter.registeredOnly)
                      for (final block in dayBlocks[i].planned)
                        _clampedTimedPositioned(
                          start: block.start,
                          end: block.end,
                          date: dates[i],
                          left: layouts[i].left,
                          width: layouts[i].width,
                          pxPerMinute: pxPerMinute,
                          // Opens the same add-actual sheet an empty-space
                          // tap does, prefilled from the plan itself (time,
                          // title, goal) — logging what was already planned
                          // shouldn't mean retyping it.
                          childBuilder: (labelStyle) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => showAddBlockSheet(
                              context,
                              ref,
                              isPlan: false,
                              date: dates[i],
                              initialStart: TimeOfDay.fromDateTime(
                                block.start,
                              ),
                              initialEnd: TimeOfDay.fromDateTime(block.end),
                              initialTitle: block.title,
                              initialGoalId: goalForCategory(
                                goals,
                                block.categoryId,
                              )?.id,
                              fromPlan: true,
                            ),
                            child: PlanBlockWidget(
                              block: block,
                              category: resolveCategory(
                                categories,
                                block.categoryId,
                              ),
                              labelStyle: labelStyle,
                            ),
                          ),
                        ),
                    // Hidden outright when the header's filter is set to
                    // "Planned only" — see [DayViewBlockFilter].
                    if (blockFilter != DayViewBlockFilter.plannedOnly)
                      for (final block in dayBlocks[i].tracked)
                        _clampedTimedPositioned(
                          start: block.start,
                          end: block.end,
                          date: dates[i],
                          // Inset from the column's own left edge — rather
                          // than fully covering a planned block for the same
                          // time (see the comment above), an actual block
                          // now always leaves a sliver of it showing on the
                          // left, so an overlap between the two reads as an
                          // overlap instead of the planned block just
                          // disappearing underneath.
                          left:
                              layouts[i].left +
                              layouts[i].width * _actualBlockInset,
                          width: layouts[i].width * (1 - _actualBlockInset),
                          pxPerMinute: pxPerMinute,
                          childBuilder: (labelStyle) => ActualBlockWidget(
                            block: block,
                            category: resolveCategory(
                              categories,
                              block.categoryId,
                            ),
                            wasPlanned: trackedBlockWasPlanned(
                              block,
                              dayBlocks[i].planned,
                            ),
                            ref: ref,
                            labelStyle: labelStyle,
                          ),
                        ),
                    // The in-progress activity itself, drawn live on every
                    // day column it overlaps (not just the one it started
                    // on — a run still going past midnight needs to show
                    // up on the new day too) — see
                    // LiveActivityRunningBlock's own doc comment. Same
                    // filter gating as the tracked blocks above: it's a
                    // real in-progress "actual", just not registered yet.
                    if (blockFilter != DayViewBlockFilter.plannedOnly &&
                        running != null &&
                        overlapsDay(running.startedAt, DateTime.now(), dates[i]))
                      _clampedTimedPositioned(
                        start: running.startedAt,
                        end: DateTime.now(),
                        date: dates[i],
                        left:
                            layouts[i].left +
                            layouts[i].width * _actualBlockInset,
                        width: layouts[i].width * (1 - _actualBlockInset),
                        pxPerMinute: pxPerMinute,
                        childBuilder: (labelStyle) => LiveActivityRunningBlock(
                          running: running,
                          category: resolveCategory(
                            categories,
                            running.categoryId,
                          ),
                          labelStyle: labelStyle,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _jumpToInitialOffset() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_initialScrollOffset);
    }
  }

  // 52px — the height two lines of text (a title plus a secondary line)
  // need to fit without overflowing. Used only to decide how much of a
  // block's label to show — never to resize the block itself, which
  // always renders at its own real start/end time with no minimum floor.
  // A block used to be clamped to this height outright, which was a
  // genuine bug a user hit directly: a 15-minute actual entry rendered
  // the exact same height, at the exact same start time, as the
  // 30-minute planned block behind it, reading as if the two exactly
  // matched when they didn't.
  static const _twoLineMinHeight = 52.0;

  // Clamps [start]/[end] to [date]'s own [00:00, 24:00) span before
  // positioning — an overnight block (started the evening before, or
  // still running past midnight) is drawn on *every* day it overlaps, not
  // just the one it started on (see overlapsDay's own doc comment for the
  // bug this fixes), so each day's own column needs only its own portion
  // of the block's real time range, not the whole thing positioned as if
  // it belonged wholly to this day.
  Positioned _clampedTimedPositioned({
    required DateTime start,
    required DateTime end,
    required DateTime date,
    required double left,
    required double width,
    required double pxPerMinute,
    required Widget Function(BlockLabelStyle labelStyle) childBuilder,
  }) {
    final (dayStart, dayEnd) = dayBounds(date);
    return _timedPositioned(
      start: start.isBefore(dayStart) ? dayStart : start,
      end: end.isAfter(dayEnd) ? dayEnd : end,
      left: left,
      width: width,
      pxPerMinute: pxPerMinute,
      childBuilder: childBuilder,
    );
  }

  Positioned _timedPositioned({
    required DateTime start,
    required DateTime end,
    required double left,
    required double width,
    required double pxPerMinute,
    required Widget Function(BlockLabelStyle labelStyle) childBuilder,
  }) {
    final startMinute = start.hour * 60 + start.minute;
    final durationMinutes = end.difference(start).inMinutes;
    final height = durationMinutes * pxPerMinute;
    // Compact always renders below the two-line floor, even on a block
    // shorter than one text line — its label overflows past the block's
    // own tiny box rather than going missing (see BlockLabelStyle's own
    // doc comment).
    final labelStyle = height >= _twoLineMinHeight
        ? BlockLabelStyle.full
        : BlockLabelStyle.compact;
    return Positioned(
      top: startMinute * pxPerMinute,
      left: left,
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
        child: childBuilder(labelStyle),
      ),
    );
  }
}

class _HourGridLine extends StatelessWidget {
  const _HourGridLine({
    required this.hour,
    required this.gutterWidth,
    required this.hourHeight,
  });

  final int hour;
  final double gutterWidth;
  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: hour * hourHeight,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: gutterWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  // hour 24 is the extra hour past midnight this grid
                  // extends into — labelled "00", matching the real clock.
                  (hour % 24).toString().padLeft(2, '0'),
                  textAlign: TextAlign.right,
                  style: AppTextStyles.mono(),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(top: 5),
                // Outlook's grid is near-invisible: a hairline per hour,
                // a touch stronger every 6 to keep the day scannable.
                color: hour % 6 == 0
                    ? AppColors.neutral500
                    : AppColors.neutral400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
