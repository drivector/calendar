import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/category.dart';
import '../../../models/goal.dart';
import '../../../models/running_activity.dart';
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
import '../../../utils/overlap_layout.dart';
import '../../goals/widgets/goal_detail_sheet.dart';
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

          List<Widget> columnChildren(int i) => _buildColumnChildren(
            context: context,
            date: dates[i],
            dayBlocks: dayBlocks[i],
            columnLeft: layouts[i].left,
            columnWidth: layouts[i].width,
            columnHeight: dayHeight,
            pxPerMinute: pxPerMinute,
            blockFilter: blockFilter,
            running: running,
            categories: categories,
            goals: goals,
          );

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
                  for (var i = 0; i < dates.length; i++) ...columnChildren(i),
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

  // Everything one day-column actually draws: the empty-space tap target,
  // then the planned lane, then the tracked/live-activity lane on top of
  // it. Both lanes lay overlapping items out side-by-side rather than
  // stacking them directly on one another (see layoutOverlaps's own doc
  // comment) — the same collision handling a calendar app gives
  // simultaneous meetings. The one exception: an actual entry that
  // matches a specific plan (same link or same category/time overlap —
  // see matchingPlannedBlockForRange) sits *over* that plan's own slot
  // instead of getting an independent one, so "this happened as planned"
  // still reads as one paired signal even when other, unrelated plans are
  // also on screen at the same time.
  List<Widget> _buildColumnChildren({
    required BuildContext context,
    required DateTime date,
    required DayBlocks dayBlocks,
    required double columnLeft,
    required double columnWidth,
    required double columnHeight,
    required double pxPerMinute,
    required DayViewBlockFilter blockFilter,
    required RunningActivity? running,
    required List<Category> categories,
    required List<Goal> goals,
  }) {
    final (dayStart, dayEnd) = dayBounds(date);
    DateTime clampStart(DateTime s) => s.isBefore(dayStart) ? dayStart : s;
    DateTime clampEnd(DateTime e) => e.isAfter(dayEnd) ? dayEnd : e;

    final children = <Widget>[
      // Added before the blocks below so any block painted on top claims
      // its own tap first.
      Positioned(
        left: columnLeft,
        top: 0,
        width: columnWidth,
        height: columnHeight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleEmptySpaceTap(details, date, pxPerMinute),
          child: const SizedBox.expand(),
        ),
      ),
    ];

    // Planned blocks paint first (dashed, unfilled) so a solid Actual
    // block for the same time reads clearly on top of it rather than the
    // two competing visually. Hidden outright when the header's filter is
    // set to "Registered only" — see [DayViewBlockFilter] — in which case
    // there's nothing left for an actual entry below to align with
    // either, so it falls back to its own independent layout.
    final showPlanned = blockFilter != DayViewBlockFilter.registeredOnly;
    final plannedSlotById = <String, ({double left, double width})>{};
    if (showPlanned) {
      for (final slot in layoutOverlaps(
        dayBlocks.planned,
        (b) => clampStart(b.start),
        (b) => clampEnd(b.end),
      )) {
        final block = slot.item;
        final slotWidth = columnWidth / slot.columnCount;
        final slotLeft = columnLeft + slot.columnIndex * slotWidth;
        plannedSlotById[block.id] = (left: slotLeft, width: slotWidth);
        children.add(
          _timedPositioned(
            start: clampStart(block.start),
            end: clampEnd(block.end),
            left: slotLeft,
            width: slotWidth,
            pxPerMinute: pxPerMinute,
            // A plan that hasn't happened yet can't have an actual entry
            // logged against it — nothing has occurred to log. Tapping it
            // instead opens something to edit the plan itself: for a
            // manually-added one, this sheet in edit mode; for one derived
            // from a goal's own recurring schedule (no standalone document
            // to edit), the goal's own detail, where that schedule lives.
            // Only a plan that's already started (or finished) opens the
            // add-actual sheet, prefilled from the plan itself (time,
            // title, goal) — logging what was already planned shouldn't
            // mean retyping it.
            childBuilder: (labelStyle) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!block.start.isAfter(DateTime.now())) {
                  showAddBlockSheet(
                    context,
                    ref,
                    isPlan: false,
                    date: date,
                    initialStart: TimeOfDay.fromDateTime(block.start),
                    initialEnd: TimeOfDay.fromDateTime(block.end),
                    initialTitle: block.title,
                    initialGoalId:
                        goalForCategory(goals, block.categoryId)?.id,
                    fromPlan: true,
                  );
                } else if (block.goalId != null) {
                  showGoalDetailSheet(context, ref, block.goalId!);
                } else {
                  showAddBlockSheet(
                    context,
                    ref,
                    isPlan: true,
                    date: date,
                    initialStart: TimeOfDay.fromDateTime(block.start),
                    initialEnd: TimeOfDay.fromDateTime(block.end),
                    initialTitle: block.title,
                    initialGoalId:
                        goalForCategory(goals, block.categoryId)?.id,
                    editingId: block.id,
                  );
                }
              },
              child: PlanBlockWidget(
                block: block,
                category: resolveCategory(categories, block.categoryId),
                labelStyle: labelStyle,
              ),
            ),
          ),
        );
      }
    }

    // Hidden outright when the header's filter is set to "Planned only" —
    // see [DayViewBlockFilter].
    if (blockFilter != DayViewBlockFilter.plannedOnly) {
      final actualItems = <_ActualLikeItem>[
        for (final block in dayBlocks.tracked)
          _ActualLikeItem(
            start: clampStart(block.start),
            end: clampEnd(block.end),
            rawStart: block.start,
            rawEnd: block.end,
            categoryId: block.categoryId,
            plannedBlockId: block.plannedBlockId,
            tracked: block,
            running: null,
          ),
        // The in-progress activity shares this lane too, drawn live on
        // every day column it overlaps (not just the one it started on —
        // a run still going past midnight needs to show up on the new
        // day too) — see LiveActivityRunningBlock's own doc comment.
        if (running != null &&
            overlapsDay(running.startedAt, DateTime.now(), date))
          _ActualLikeItem(
            start: clampStart(running.startedAt),
            end: clampEnd(DateTime.now()),
            rawStart: running.startedAt,
            rawEnd: DateTime.now(),
            categoryId: running.categoryId,
            plannedBlockId: null,
            tracked: null,
            running: running,
          ),
      ];

      // Each item's own matching plan, if any and if it's actually being
      // shown — the same matching logic that already drives the
      // dashed-outline signal, so "this was planned" and "this sits over
      // its own plan" always agree.
      final matchedGroups = <String, List<_ActualLikeItem>>{};
      final unmatched = <_ActualLikeItem>[];
      for (final item in actualItems) {
        final matchedPlan = showPlanned
            ? matchingPlannedBlockForRange(
                start: item.rawStart,
                end: item.rawEnd,
                categoryId: item.categoryId,
                planned: dayBlocks.planned,
                plannedBlockId: item.plannedBlockId,
              )
            : null;
        if (matchedPlan != null && plannedSlotById.containsKey(matchedPlan.id)) {
          matchedGroups.putIfAbsent(matchedPlan.id, () => []).add(item);
        } else {
          unmatched.add(item);
        }
      }

      Widget actualChild(_ActualLikeItem item, BlockLabelStyle labelStyle) {
        final liveRunning = item.running;
        if (liveRunning != null) {
          return LiveActivityRunningBlock(
            running: liveRunning,
            category: resolveCategory(categories, liveRunning.categoryId),
            labelStyle: labelStyle,
          );
        }
        final block = item.tracked!;
        return ActualBlockWidget(
          block: block,
          category: resolveCategory(categories, block.categoryId),
          wasPlanned: matchingPlannedBlockFor(block, dayBlocks.planned) != null,
          ref: ref,
          labelStyle: labelStyle,
        );
      }

      void addLaidOutActuals(
        List<_ActualLikeItem> items,
        double laneLeft,
        double laneWidth,
      ) {
        for (final slot in layoutOverlaps(
          items,
          (it) => it.start,
          (it) => it.end,
        )) {
          final slotWidth = laneWidth / slot.columnCount;
          final slotLeft = laneLeft + slot.columnIndex * slotWidth;
          children.add(
            _timedPositioned(
              start: slot.item.start,
              end: slot.item.end,
              left: slotLeft,
              width: slotWidth,
              pxPerMinute: pxPerMinute,
              childBuilder: (labelStyle) => actualChild(slot.item, labelStyle),
            ),
          );
        }
      }

      // Unmatched items get their own independent side-by-side layout,
      // within the usual inset lane — rather than fully covering a
      // planned block for the same time, an actual block always leaves a
      // sliver of it showing on the left, so an overlap between the two
      // reads as an overlap instead of the planned block just
      // disappearing underneath.
      addLaidOutActuals(
        unmatched,
        columnLeft + columnWidth * _actualBlockInset,
        columnWidth * (1 - _actualBlockInset),
      );

      // Matched items sit inside their own plan's own slot instead — the
      // same inset convention, just scaled to that slot's own width
      // rather than the whole column, and split further if more than one
      // actual entry somehow matches the very same plan.
      for (final entry in matchedGroups.entries) {
        final planSlot = plannedSlotById[entry.key]!;
        addLaidOutActuals(
          entry.value,
          planSlot.left + planSlot.width * _actualBlockInset,
          planSlot.width * (1 - _actualBlockInset),
        );
      }
    }

    return children;
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

/// A real [TrackedBlock] or the currently in-progress [RunningActivity],
/// unified into one shape so both can go through the same overlap layout
/// and matching-to-a-plan logic in [_TimeBodyGridState._buildColumnChildren]
/// — exactly one of [tracked]/[running] is ever set. [start]/[end] are
/// already clamped to the day column being laid out; [rawStart]/[rawEnd]
/// stay the item's own real, unclamped span, since matching against a
/// plan needs the real overlap, not just today's own visible portion.
class _ActualLikeItem {
  const _ActualLikeItem({
    required this.start,
    required this.end,
    required this.rawStart,
    required this.rawEnd,
    required this.categoryId,
    required this.plannedBlockId,
    required this.tracked,
    required this.running,
  });

  final DateTime start;
  final DateTime end;
  final DateTime rawStart;
  final DateTime rawEnd;
  final String categoryId;
  final String? plannedBlockId;
  final TrackedBlock? tracked;
  final RunningActivity? running;
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
