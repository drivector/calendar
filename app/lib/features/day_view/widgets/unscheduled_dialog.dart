import 'package:flutter/material.dart' show Dialog, showDialog;
import 'package:flutter/widgets.dart';

import '../../../models/category.dart';
import '../../../models/goal.dart';
import '../../../state/categories_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';

/// The legend row's "unscheduled" item, tapped — a breakdown of exactly
/// the total shown there: goal-targeted time with no fixed clock slot for
/// whichever day(s) are currently visible, one row per goal, a real total
/// at the top so it doesn't have to be added up by eye.
Future<void> showUnscheduledDialog(
  BuildContext context, {
  required Map<String, Duration> byGoal,
  required List<Goal> goals,
  required List<Category> categories,
}) {
  final entries =
      byGoal.entries
          .map((e) => (goal: goalById(goals, e.key), duration: e.value))
          .where((e) => e.goal != null)
          .toList()
        ..sort((a, b) => b.duration.compareTo(a.duration));
  final total = entries.fold(Duration.zero, (t, e) => t + e.duration);

  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s6,
        vertical: AppSpacing.s6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          minWidth: MediaQuery.of(context).size.width * 0.6,
          maxWidth: MediaQuery.of(context).size.width * 0.8,
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
                  Text('Unscheduled', style: AppTextStyles.title()),
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
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  child: Text('Nothing unscheduled.', style: AppTextStyles.mono()),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: AppTextStyles.kicker()),
                    Text(formatDuration(total), style: AppTextStyles.kicker()),
                  ],
                ),
                const SizedBox(height: AppSpacing.s1),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: const SizedBox(height: 1, width: double.infinity),
                ),
                const SizedBox(height: AppSpacing.s2),
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.goal!.name.toLowerCase(),
                          style: AppTextStyles.mono(
                            color: resolveCategory(
                              categories,
                              entry.goal!.categoryId,
                            ).color,
                          ),
                        ),
                        Text(
                          formatDuration(entry.duration),
                          style: AppTextStyles.mono(color: AppColors.text),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
