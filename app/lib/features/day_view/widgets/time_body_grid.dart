import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/tracked_block.dart';
import '../../../shared/widgets/date_swipe_nav.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'actual_block_widget.dart';
import 'add_block_sheet.dart';
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
const _pxPerMinute = 1.2;
const _hourHeight = 60 * _pxPerMinute;
// One hour past midnight, not a bare 24 — scrolling all the way down still
// leaves a full hour of the next day visible instead of stopping dead at
// the 00 line.
const _dayHeight = 25 * _hourHeight;

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

  // A fixed 18:00 anchor, the same in every view mode — entering the
  // Calendar tab (or changing date/mode) always lands on the evening
  // rather than wherever the day's own first event happens to be.
  static double get _initialScrollOffset => 18 * 60 * _pxPerMinute;

  // Always logs an actual entry — with Plan and Actual sharing one slot
  // now, there's no separate Plan-only region left to tap for a manual
  // planned block; planned blocks come from a goal's own schedule instead.
  void _handleEmptySpaceTap(TapUpDetails details, DateTime date) {
    final minutes = (details.localPosition.dy / _pxPerMinute).round();
    final rounded = ((minutes / 15).round() * 15).clamp(0, 24 * 60 - 30);
    showAddBlockSheet(
      context,
      ref,
      isPlan: false,
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

    final dates = ref.watch(visibleDatesProvider);
    final dayBlocks = ref.watch(visibleDayBlocksProvider);
    final categories = ref.watch(categoriesProvider);
    final goals = ref.watch(goalsProvider);

    return DateSwipeNav(
      onPrevious: () => stepDayViewWindow(ref, forward: false),
      onNext: () => stepDayViewWindow(ref, forward: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layouts = columnLayoutsFor(constraints.maxWidth, dates.length);

          return SingleChildScrollView(
            controller: _scrollController,
            child: SizedBox(
              height: _dayHeight,
              width: double.infinity,
              child: Stack(
                children: [
                  for (var hour = 0; hour <= 24; hour++)
                    _HourGridLine(hour: hour, gutterWidth: kGutterWidth),
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
                        height: _dayHeight,
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
                      height: _dayHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) =>
                            _handleEmptySpaceTap(details, dates[i]),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // Planned blocks paint first (dashed, unfilled) so a
                    // solid Actual block for the same time reads clearly on
                    // top of it rather than the two competing visually.
                    for (final block in dayBlocks[i].planned)
                      _timedPositioned(
                        start: block.start,
                        end: block.end,
                        left: layouts[i].left,
                        width: layouts[i].width,
                        // Opens the same add-actual sheet an empty-space
                        // tap does, prefilled from the plan itself (time,
                        // title, goal) — logging what was already planned
                        // shouldn't mean retyping it.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => showAddBlockSheet(
                            context,
                            ref,
                            isPlan: false,
                            date: dates[i],
                            initialStart: TimeOfDay.fromDateTime(block.start),
                            initialEnd: TimeOfDay.fromDateTime(block.end),
                            initialTitle: block.title,
                            initialGoalId: goalForCategory(
                              goals,
                              block.categoryId,
                            )?.id,
                          ),
                          child: PlanBlockWidget(
                            block: block,
                            category: resolveCategory(
                              categories,
                              block.categoryId,
                            ),
                          ),
                        ),
                      ),
                    for (final block in dayBlocks[i].tracked)
                      _timedPositioned(
                        start: block.start,
                        end: block.end,
                        // Inset from the column's own left edge — rather
                        // than fully covering a planned block for the same
                        // time (see the comment above), an actual block
                        // now always leaves a sliver of it showing on the
                        // left, so an overlap between the two reads as an
                        // overlap instead of the planned block just
                        // disappearing underneath.
                        left: layouts[i].left + layouts[i].width * _actualBlockInset,
                        width: layouts[i].width * (1 - _actualBlockInset),
                        child: ActualBlockWidget(
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

  Positioned _timedPositioned({
    required DateTime start,
    required DateTime end,
    required double left,
    required double width,
    required Widget child,
  }) {
    final startMinute = start.hour * 60 + start.minute;
    final durationMinutes = end.difference(start).inMinutes;
    return Positioned(
      top: startMinute * _pxPerMinute,
      left: left,
      width: width,
      // 52px minimum — short blocks (e.g. a 30-minute manual entry) need
      // room for two lines of text without overflowing; the original mock
      // data happened to always be >=40 minutes, which is why this only
      // surfaced once a shorter block was added. Raised from 44 when the
      // Outlook restyle grew the type ramp (label 12→14, mono 11→12): the
      // two lines plus padding no longer fit the old minimum.
      height: (durationMinutes * _pxPerMinute).clamp(52.0, double.infinity),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
        child: child,
      ),
    );
  }
}

class _HourGridLine extends StatelessWidget {
  const _HourGridLine({required this.hour, required this.gutterWidth});

  final int hour;
  final double gutterWidth;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: hour * _hourHeight,
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
