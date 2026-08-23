import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/planned_block.dart';
import '../../../models/tracked_block.dart';
import '../../../shared/widgets/date_swipe_nav.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/derived_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'actual_block_widget.dart';
import 'add_block_sheet.dart';
import 'column_headers.dart';
import 'plan_block_widget.dart';
import 'untracked_gap_widget.dart';

/// A continuous, scrollable 24-hour timeline — hour rows at a fixed height,
/// events positioned and sized by their real clock time, the way a standard
/// calendar app's day view works (Google/Apple Calendar), rather than one
/// row per planned block. Plan and Actual still run as two lanes side by
/// side so the comparison the app is built around stays visible. Tapping
/// empty space in either lane opens [showAddBlockSheet] to add a new entry
/// there; tapping an existing block or gap opens its own sheet instead,
/// since those are painted on top and claim the hit first.
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
const _dayHeight = 24 * _hourHeight;

class _TimeBodyGridState extends ConsumerState<TimeBodyGrid> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _scrollOffsetForFirstEvent(
        ref.read(plannedBlocksProvider),
        ref.read(trackedBlocksProvider),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static double _scrollOffsetForFirstEvent(
    List<PlannedBlock> planned,
    List<TrackedBlock> tracked,
  ) {
    final starts = [
      ...planned.map((b) => b.start),
      ...tracked.map((b) => b.start),
    ];
    final earliestMinute = starts.isEmpty
        ? 7 * 60
        : starts.map((d) => d.hour * 60 + d.minute).reduce((a, b) => a < b ? a : b);
    return ((earliestMinute - 60).clamp(0, 24 * 60 - 1)) * _pxPerMinute;
  }

  void _handleLaneTap(TapUpDetails details, {required bool isPlan}) {
    final minutes = (details.localPosition.dy / _pxPerMinute).round();
    final rounded = ((minutes / 15).round() * 15).clamp(0, 24 * 60 - 30);
    showAddBlockSheet(
      context,
      ref,
      isPlan: isPlan,
      initialStart: TimeOfDay(hour: rounded ~/ 60, minute: rounded % 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Changing the selected date — from the day-to-day swipe below, or from
    // tapping a day in the Week view — re-centers the timeline on that new
    // day's first event.
    ref.listen<DateTime>(selectedDateProvider, (previous, next) {
      if (previous == next) return;
      final target = _scrollOffsetForFirstEvent(
        ref.read(plannedBlocksProvider),
        ref.read(trackedBlocksProvider),
      );
      if (_scrollController.hasClients) _scrollController.jumpTo(target);
    });

    final planned = ref.watch(plannedBlocksProvider);
    final tracked = ref.watch(trackedBlocksProvider);
    final gaps = ref.watch(untrackedGapsProvider);
    final dayLayer = ref.watch(dayLayerProvider);
    final categories = ref.watch(categoriesProvider);
    final showPlan = dayLayer == DayLayer.planAndActual;

    return DateSwipeNav(
      onPrevious: () {
        final current = ref.read(selectedDateProvider);
        ref.read(selectedDateProvider.notifier).state =
            current.subtract(const Duration(days: 1));
      },
      onNext: () {
        final current = ref.read(selectedDateProvider);
        ref.read(selectedDateProvider.notifier).state =
            current.add(const Duration(days: 1));
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final laneAreaWidth = constraints.maxWidth - kGutterWidth;
          final laneWidth = showPlan ? laneAreaWidth / 2 : laneAreaWidth;
          final planLeft = kGutterWidth;
          final actualLeft = showPlan ? kGutterWidth + laneWidth : kGutterWidth;

          return SingleChildScrollView(
            controller: _scrollController,
            child: SizedBox(
              height: _dayHeight,
              width: double.infinity,
              child: Stack(
                children: [
                  for (var hour = 0; hour < 24; hour++)
                    _HourGridLine(hour: hour, gutterWidth: kGutterWidth),
                  if (showPlan)
                    Positioned(
                      left: kGutterWidth + laneWidth,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 1, color: AppColors.divider),
                    ),
                  // Empty-space tap targets — added before the blocks below
                  // so any block painted on top claims its own tap first.
                  if (showPlan)
                    Positioned(
                      left: planLeft,
                      top: 0,
                      width: laneWidth,
                      height: _dayHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _handleLaneTap(details, isPlan: true),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  Positioned(
                    left: actualLeft,
                    top: 0,
                    width: laneWidth,
                    height: _dayHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _handleLaneTap(details, isPlan: false),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  for (final block in planned)
                    if (showPlan)
                      _timedPositioned(
                        start: block.start,
                        end: block.end,
                        left: planLeft,
                        width: laneWidth,
                        child: PlanBlockWidget(block: block),
                      ),
                  for (final block in tracked)
                    _timedPositioned(
                      start: block.start,
                      end: block.end,
                      left: actualLeft,
                      width: laneWidth,
                      child: ActualBlockWidget(
                        block: block,
                        category: resolveCategory(categories, block.categoryId),
                      ),
                    ),
                  for (final gap in gaps)
                    _timedPositioned(
                      start: gap.start,
                      end: gap.end,
                      left: actualLeft,
                      width: laneWidth,
                      child: UntrackedGapWidget(gap: gap),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
      // 44px minimum — short blocks (e.g. a 30-minute manual entry) need
      // room for two lines of text without overflowing; the original mock
      // data happened to always be >=40 minutes, which is why this only
      // surfaced once a shorter block was added.
      height: (durationMinutes * _pxPerMinute).clamp(44.0, double.infinity),
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
                  hour.toString().padLeft(2, '0'),
                  textAlign: TextAlign.right,
                  style: AppTextStyles.mono(),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(top: 5),
                color: hour % 6 == 0 ? AppColors.divider : AppColors.ink(0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
