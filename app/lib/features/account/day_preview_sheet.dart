import 'package:flutter/material.dart' show Dialog, showDialog;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../models/category.dart';
import '../../models/day_capacity.dart';
import '../../models/goal.dart';
import '../../models/planned_block.dart';
import '../../state/categories_providers.dart';
import '../../state/goals_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../day_view/widgets/block_label_style.dart';
import '../day_view/widgets/plan_block_widget.dart';

/// A much smaller, read-only replica of the Day view's own timeline — just
/// that one day's planned blocks, positioned by their real clock time
/// (with an hour gutter alongside, same idea as the Day view's own) against
/// the day's own tracking window, or a plain 24h axis if it has none. No
/// tap-to-add, no tracked/actual blocks, no navigating on to the real Day
/// view — a quick look, nothing more. A floating pop-up (not a sheet
/// sliding up from the bottom) — it's a glance at another screen's data,
/// not a form or a flow of its own.
Future<void> showDayPreviewSheet(
  BuildContext context, {
  required DayCapacity day,
  required List<Category> categories,
  required List<Goal> goals,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _DayPreviewDialog(day: day, categories: categories, goals: goals),
  );
}

const double _pxPerMinute = 0.4;
const double _twoLineMinHeight = 52;
const double _gutterWidth = 34;

class _DayPreviewDialog extends StatelessWidget {
  const _DayPreviewDialog({
    required this.day,
    required this.categories,
    required this.goals,
  });

  final DayCapacity day;
  final List<Category> categories;
  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    final windowStart = day.windowStart;
    final windowEnd = day.windowEnd;
    final hasWindow =
        windowStart != null &&
        windowEnd != null &&
        windowEnd.isAfter(windowStart);
    final dayStart = DateTime(day.date.year, day.date.month, day.date.day);
    final axisStart = hasWindow ? windowStart : dayStart;
    final axisEnd = hasWindow
        ? windowEnd
        : dayStart.add(const Duration(days: 1));
    final timelineHeight =
        axisEnd.difference(axisStart).inMinutes * _pxPerMinute;

    // Sorted, then clipped to a non-overlapping sequence — two blocks
    // covering the same real time (e.g. a goal scheduled during a "sleep"
    // stretch) would otherwise stack directly on top of each other, and
    // whichever drew second would visually swallow the first's own label.
    final sortedBlocks = [...day.plannedBlocks]
      ..sort((a, b) => a.start.compareTo(b.start));
    final blocks = <(PlannedBlock, DateTime, DateTime)>[];
    var cursor = axisStart;
    for (final block in sortedBlocks) {
      final start = block.start.isBefore(cursor) ? cursor : block.start;
      final end = block.end.isAfter(axisEnd) ? axisEnd : block.end;
      if (!end.isAfter(start)) continue;
      blocks.add((block, start, end));
      cursor = end;
    }
    final hourMarks = _hourMarksBetween(axisStart, axisEnd);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          minWidth: MediaQuery.of(context).size.width * 0.6,
          maxWidth: MediaQuery.of(context).size.width * 0.6,
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
                    DateFormat('EEEE, d MMM').format(day.date),
                    style: AppTextStyles.title(),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'close',
                        style: AppTextStyles.small(color: AppColors.accent),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              if (blocks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  child: Text(
                    'Nothing planned this day.',
                    style: AppTextStyles.mono(),
                  ),
                )
              else
                SizedBox(
                  height: timelineHeight,
                  child: Stack(
                    children: [
                      for (final hour in hourMarks)
                        _hourGridLine(hour, axisStart),
                      for (final (block, start, end) in blocks)
                        _blockPositioned(block, start, end, axisStart),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Positioned _hourGridLine(DateTime hour, DateTime axisStart) {
    final top = hour.difference(axisStart).inMinutes * _pxPerMinute;
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _gutterWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  hour.hour.toString().padLeft(2, '0'),
                  textAlign: TextAlign.right,
                  style: AppTextStyles.mono(),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(top: 5),
                color: AppColors.neutral400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Positioned _blockPositioned(
    PlannedBlock block,
    DateTime start,
    DateTime end,
    DateTime axisStart,
  ) {
    final startMinute = start.difference(axisStart).inMinutes;
    final durationMinutes = end.difference(start).inMinutes;
    final height = durationMinutes * _pxPerMinute;
    final labelStyle = height >= _twoLineMinHeight
        ? BlockLabelStyle.full
        : BlockLabelStyle.compact;

    return Positioned(
      top: startMinute * _pxPerMinute,
      left: _gutterWidth,
      right: 0,
      height: height,
      child: PlanBlockWidget(
        block: block,
        category: resolveCategory(
          categories,
          goalById(goals, block.goalId)?.categoryId ?? '',
        ),
        labelStyle: labelStyle,
      ),
    );
  }
}

/// Every other whole hour (00, 02, 04, ...) within [axisStart, axisEnd] —
/// every single hour read as too dense/tall for a "much smaller" preview.
/// The window's own bounds usually don't land exactly on an even hour, so
/// this starts from the first even hour at or after [axisStart] rather
/// than assuming it does.
List<DateTime> _hourMarksBetween(DateTime axisStart, DateTime axisEnd) {
  var cursor = DateTime(
    axisStart.year,
    axisStart.month,
    axisStart.day,
    axisStart.hour - axisStart.hour % 2,
  );
  if (cursor.isBefore(axisStart)) cursor = cursor.add(const Duration(hours: 2));
  final marks = <DateTime>[];
  while (!cursor.isAfter(axisEnd)) {
    marks.add(cursor);
    cursor = cursor.add(const Duration(hours: 2));
  }
  return marks;
}
