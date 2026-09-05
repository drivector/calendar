import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/categories_providers.dart';
import '../../../state/derived_providers.dart';
import '../../../shared/widgets/capacity_track.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';
import 'unscheduled_dialog.dart';

/// The calendar's summary strip: how much of the tracking window the
/// visible days have actually been filled with.
///
/// This replaced four swatched absolutes ("tracked 9h · planned 2h 30m ·
/// registered 4h 15m · unscheduled 45m"). Those stated no relationship
/// between each other — the question worth answering is "how much of my
/// window did I fill?", which the reader had to divide out by hand — and
/// in the multi-day modes the words themselves were hidden behind a
/// tap-to-reveal, leaving three unlabelled numbers.
///
/// Now: one caption row reading in the same order as the bar's segments
/// (`4h 15m done · 2h 30m planned` … `of 9h`), the bar itself, and the
/// unscheduled line below it. The bar's colours *are* the legend, so the
/// swatches are gone.
///
/// Terms are [dayTotalsProvider]'s, unchanged — "tracked" is the user's
/// configured tracking window (the bar's full track), "registered" is
/// really-logged time (the solid fill), "planned" is only blocks with a
/// real clock time (the dashed fill), and "unscheduled" is goal-targeted
/// time with no slot at all, which is why it gets a line of its own
/// rather than a segment.
///
/// In 3 Day/Working week/Week mode the caption, the height and the
/// unscheduled line are identical; only the bar changes, splitting into
/// one track per visible day (see [visibleDayTotalsProvider]) so a day
/// with nothing logged shows as its own empty track instead of averaging
/// away into the week's total.
class LegendRow extends ConsumerWidget {
  const LegendRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (plannedTotal, trackedTotal, registeredTotal, unscheduledTotal) =
        ref.watch(dayTotalsProvider);
    final perDay = ref.watch(visibleDayTotalsProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Flexible + ellipsis: the left caption is the part that
                // grows with the totals, and a long one on a narrow phone
                // is exactly what used to overflow this row.
                Flexible(
                  child: Text(
                    '${formatDuration(registeredTotal)} done'
                    ' · ${formatDuration(plannedTotal)} planned',
                    style: AppTextStyles.mono(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  'of ${formatDuration(trackedTotal)}',
                  style: AppTextStyles.mono(),
                  maxLines: 1,
                ),
              ],
            ),
            const SizedBox(height: 6),
            CapacityBar(days: perDay),
            // Only shown when there's actually a goal owed some time it
            // hasn't been given a fixed slot for yet — otherwise every
            // account with fully-scheduled goals (the common case) would
            // carry a permanent "0m unscheduled" line for nothing.
            if (unscheduledTotal > Duration.zero)
              _UnscheduledLine(
                total: unscheduledTotal,
                onTap: () => showUnscheduledDialog(
                  context,
                  byGoal: ref.read(unscheduledByGoalProvider),
                  goals: ref.read(goalsProvider),
                  categories: ref.read(categoriesProvider),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The bar: one [CapacityTrack] per visible day, sharing the row's width
/// equally. Equal flex rather than flex-by-window-length, so a short
/// Saturday window still reads as its own full-height day rather than a
/// sliver — the fills within each track are what carry the proportion.
class CapacityBar extends StatelessWidget {
  const CapacityBar({super.key, required this.days});

  final List<VisibleDayTotals> days;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: CapacityTrack(
              filled: days[i].registered,
              hatched: days[i].planned,
              total: days[i].tracked,
            ),
          ),
        ],
      ],
    );
  }
}

class _UnscheduledLine extends StatelessWidget {
  const _UnscheduledLine({required this.total, required this.onTap});

  final Duration total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // A real tap target even though the text alone is short — matches
      // this app's own ≥32×32 convention for anything tappable.
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.centerLeft,
        child: Text(
          '${formatDuration(total)} unscheduled ›',
          style: AppTextStyles.mono(),
        ),
      ),
    );
  }
}
