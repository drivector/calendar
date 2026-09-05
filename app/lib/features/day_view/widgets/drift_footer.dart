import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/category.dart';
import '../../../models/drift.dart';
import '../../../models/goal.dart';
import '../../../shared/widgets/capacity_track.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/derived_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';

/// The goal's own name, lowercased to match this footer's own style —
/// every [GoalDrift] entry now resolves to a real goal (see
/// `computeDrift`'s own doc comment), so this falls back to the category's
/// name only if that goal has since gone missing from [goals] entirely.
String _driftLabel(List<Goal> goals, List<Category> categories, GoalDrift entry) {
  for (final goal in goals) {
    if (goal.id == entry.goalId) return goal.name.toLowerCase();
  }
  return resolveCategory(categories, entry.categoryId).name.toLowerCase();
}

class DriftFooter extends ConsumerWidget {
  const DriftFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drift = ref.watch(driftProvider);
    final categories = ref.watch(categoriesProvider);
    final goals = ref.watch(goalsProvider);
    // Only genuinely "today" in Day mode, and only when the selected day
    // isn't in the future — [driftProvider] now sums across every visible
    // day, so the label needs to stop claiming "today" once there's more
    // than one day on screen, or once Day mode is showing a day that
    // hasn't happened yet (mirrors [driftProvider]'s own "future days
    // excluded" cutoff, not a strict same-day check — a past selected day
    // still reads as "today" the same way [driftProvider] still sums it).
    final isDayMode = ref.watch(dayViewModeProvider) == DayViewMode.day;
    final selectedDate = ref.watch(selectedDateProvider);
    final isToday = isDayMode && !selectedDate.isAfter(today());

    // Drift is only ever about days that have actually elapsed. When every
    // visible day is still in the future — Day mode on a day next month, or
    // a whole week scrolled ahead — there's nothing that *could* be behind
    // plan, and the footer used to sit there as a bare "DRIFT" heading with
    // no rows under it. Hide the whole thing instead. (An on-plan present
    // day still shows the heading with nothing under it: that's a real
    // "you're not behind on anything", not an empty question.)
    final hasElapsedDay = ref
        .watch(visibleDatesProvider)
        .any((date) => !date.isAfter(today()));
    if (!hasElapsedDay) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
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
            Text(
              isToday ? 'DRIFT TODAY' : 'DRIFT',
              style: AppTextStyles.kicker(),
            ),
            const SizedBox(height: AppSpacing.s1),
            // Only goals still short of their plan are "drift" — one that's
            // met or exceeded it is fine, not something to flag here.
            for (final entry in drift)
              if (entry.delta.inMinutes < 0)
                _DriftRow(
                  label: _driftLabel(goals, categories, entry),
                  color: resolveCategory(categories, entry.categoryId).color,
                  entry: entry,
                ),
          ],
        ),
      ),
    );
  }
}

/// One goal's row: its name, a bar of how much of its own plan it
/// actually got, and the shortfall.
///
/// The bar is the same [CapacityTrack] the header's capacity bar is built
/// from, in the goal's own category colour — a signed delta on its own
/// says nothing about scale, and "−30m" means very different things
/// against a 30m goal and an 8h one.
class _DriftRow extends StatelessWidget {
  const _DriftRow({
    required this.label,
    required this.color,
    required this.entry,
  });

  final String label;
  final Color color;
  final GoalDrift entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // A fixed share of the row rather than intrinsic width, so the
          // bars all start and end at the same x down the column — a
          // ragged left edge would make them unreadable against each
          // other, which is the whole point of showing them together.
          SizedBox(
            width: 96,
            child: Text(
              // The whole word in the category's own color, not just a
              // small swatch next to it. Labelled by the goal's own name
              // when there is one — a category backing more than one goal
              // (e.g. "job" and a "side project" both under "work") would
              // otherwise show two identically-labelled rows.
              label,
              style: AppTextStyles.mono(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: CapacityTrack(
              filled: entry.tracked,
              total: entry.planned,
              fillColor: color,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          // Fixed width, like the label — otherwise each row's delta takes
          // its own intrinsic width ("−7h 15m" against "−1h") and every
          // bar ends at a different x, which makes the column of bars
          // unreadable against each other.
          SizedBox(
            width: 64,
            child: Text(
              formatSignedDuration(entry.delta),
              style: AppTextStyles.mono(color: AppColors.text),
              textAlign: TextAlign.right,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
