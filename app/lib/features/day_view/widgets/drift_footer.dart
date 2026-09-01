import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/derived_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';

class DriftFooter extends ConsumerWidget {
  const DriftFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drift = ref.watch(driftProvider);
    final categories = ref.watch(categoriesProvider);
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Same colored-bar convention as the Activities
                          // list and the block widgets — the category's
                          // own color, not plain text.
                          Container(
                            width: 3,
                            height: 12,
                            color: resolveCategory(
                              categories,
                              entry.categoryId,
                            ).color,
                          ),
                          const SizedBox(width: AppSpacing.s1),
                          Text(
                            resolveCategory(
                              categories,
                              entry.categoryId,
                            ).name.toLowerCase(),
                            style: AppTextStyles.mono(color: AppColors.text),
                          ),
                        ],
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
