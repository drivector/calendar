import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/category.dart';
import '../../../models/drift.dart';
import '../../../models/goal.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/derived_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';

/// The goal's own name when [entry] resolved to one, lowercased to match
/// this footer's own style; otherwise the category's name, for the rare
/// row backed by no goal at all (e.g. its goal was since deleted).
String _driftLabel(List<Goal> goals, List<Category> categories, GoalDrift entry) {
  if (entry.goalId != null) {
    for (final goal in goals) {
      if (goal.id == entry.goalId) return goal.name.toLowerCase();
    }
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
    // Only genuinely "today" in Day mode — [driftProvider] now sums across
    // every visible day, so the label needs to stop claiming "today" once
    // there's more than one day on screen.
    final isDayMode = ref.watch(dayViewModeProvider) == DayViewMode.day;

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
              isDayMode ? 'DRIFT TODAY' : 'DRIFT',
              style: AppTextStyles.kicker(),
            ),
            const SizedBox(height: AppSpacing.s1),
            for (final entry in drift)
              if (entry.delta.inMinutes != 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        // The whole word in the category's own color, not
                        // just a small swatch next to it. Labelled by the
                        // goal's own name when there is one — a category
                        // backing more than one goal (e.g. "job" and a
                        // "side project" both under "work") would
                        // otherwise show two identically-labelled rows.
                        _driftLabel(goals, categories, entry),
                        style: AppTextStyles.mono(
                          color: resolveCategory(
                            categories,
                            entry.categoryId,
                          ).color,
                        ),
                      ),
                      Text(
                        formatSignedDuration(entry.delta),
                        style: AppTextStyles.mono(color: AppColors.text),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
