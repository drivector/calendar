import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/categories_providers.dart';
import '../../../state/derived_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
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
              registered: days[i].registered,
              planned: days[i].planned,
              tracked: days[i].tracked,
            ),
          ),
        ],
      ],
    );
  }
}

/// One day's track — solid accent for [registered], a hatched lighter
/// fill for [planned], the rest left as bare track. Planned is hatched
/// rather than merely tinted so it reads as planned-not-yet-happened at a
/// glance, the same way a planned block on the timeline is dashed while a
/// logged one is solid.
///
/// The two fills are laid out by integer flex over [kFlexResolution]
/// rather than by fractional widths, so they stay exact at any track
/// width. Together they're clamped to the whole track: a day logged and
/// planned past its own window renders as full, not as an overflow.
class CapacityTrack extends StatelessWidget {
  const CapacityTrack({
    super.key,
    required this.registered,
    required this.planned,
    required this.tracked,
  });

  static const double height = 6;

  /// Flex units one full track is divided into. 1000 puts the rounding
  /// error below a tenth of a percent — invisible at this height.
  static const int kFlexResolution = 1000;

  final Duration registered;
  final Duration planned;
  final Duration tracked;

  int _flex(Duration part) {
    if (tracked <= Duration.zero) return 0;
    return (part.inSeconds * kFlexResolution / tracked.inSeconds)
        .round()
        .clamp(0, kFlexResolution);
  }

  @override
  Widget build(BuildContext context) {
    final registeredFlex = _flex(registered);
    // Whatever's left after the solid fill — a day already over its
    // window has no room left to draw the planned time in.
    final plannedFlex = _flex(
      planned,
    ).clamp(0, kFlexResolution - registeredFlex);
    final remainder = kFlexResolution - registeredFlex - plannedFlex;

    return ClipRRect(
      borderRadius: AppShapes.small,
      child: SizedBox(
        height: height,
        // stretch, not the default centre: a childless ColoredBox given
        // loose vertical constraints sizes itself to zero height, so the
        // fills paint nothing at all. Only caught by looking at the real
        // app — a widget test asserting fill *widths* passes either way.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (registeredFlex > 0)
              Expanded(
                flex: registeredFlex,
                child: const ColoredBox(color: AppColors.accent),
              ),
            if (plannedFlex > 0)
              Expanded(
                flex: plannedFlex,
                child: const _HatchFill(),
              ),
            if (remainder > 0)
              Expanded(
                flex: remainder,
                child: const ColoredBox(color: AppColors.neutral300),
              ),
          ],
        ),
      ),
    );
  }
}

/// The planned segment's fill: accent diagonal stripes on white, the
/// flat-colour cousin of the dashed outline [DashedRectBorder] gives a
/// planned block on the timeline. A dashed *outline* would collapse to
/// mush inside a 6px-tall segment, so the texture goes inside instead.
class _HatchFill extends StatelessWidget {
  const _HatchFill();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _HatchPainter());
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter();

  static const double _spacing = 4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.surface,
    );
    final paint = Paint()
      ..color = AppColors.accent300
      ..strokeWidth = 2;
    // 45° stripes: walk x from -height so the first stripe's bottom-left
    // corner still crosses the segment rather than starting mid-way in.
    for (var x = -size.height; x < size.width; x += _spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => false;
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
