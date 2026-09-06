import 'package:flutter/material.dart' show Dialog, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/category.dart';
import '../../../models/goal.dart';
import '../../../shared/widgets/inline_form_error.dart';
import '../../../shared/widgets/quick_log_check_button.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
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
///
/// [date] is the single day each row's checkmark logs against (see
/// [logUnscheduledGoalTime]) — null hides the checkmark entirely, since
/// [byGoal] can be summed across more than one visible day (3 Day/Working
/// week/Week mode), and there'd be no honest single day left to credit
/// that time to.
Future<void> showUnscheduledDialog(
  BuildContext context, {
  required WidgetRef ref,
  required Map<String, Duration> byGoal,
  required List<Goal> goals,
  required List<Category> categories,
  DateTime? date,
}) {
  final entries =
      byGoal.entries
          .map((e) => (goal: goalById(goals, e.key), duration: e.value))
          // A goal whose untimed budget is now fully credited (a manual
          // plan or a real tracked activity covering all of it) sits in
          // the map at exactly zero rather than being removed from it —
          // see untimedPlannedDurationByGoalForDate's own clamped-at-zero
          // behaviour. Filtered out here rather than there, since zero is
          // still meaningful to that function's other callers (drift
          // needs the goal to keep contributing to its own totals even
          // once its untimed portion hits zero).
          .where((e) => e.goal != null && e.duration > Duration.zero)
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
        child: _UnscheduledDialogContent(
          ref: ref,
          entries: entries,
          total: total,
          categories: categories,
          date: date,
        ),
      ),
    ),
  );
}

class _UnscheduledDialogContent extends StatefulWidget {
  const _UnscheduledDialogContent({
    required this.ref,
    required this.entries,
    required this.total,
    required this.categories,
    required this.date,
  });

  final WidgetRef ref;
  final List<({Goal? goal, Duration duration})> entries;
  final Duration total;
  final List<Category> categories;
  final DateTime? date;

  @override
  State<_UnscheduledDialogContent> createState() =>
      _UnscheduledDialogContentState();
}

class _UnscheduledDialogContentState extends State<_UnscheduledDialogContent> {
  String? _errorMessage;

  Future<void> _quickLog(Goal goal, Duration duration) async {
    try {
      await logUnscheduledGoalTime(
        widget.ref,
        goal: goal,
        date: widget.date!,
        duration: duration,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _errorMessage = kSaveFailedMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
          if (_errorMessage != null) ...[
            InlineFormError(_errorMessage!),
            const SizedBox(height: AppSpacing.s2),
          ],
          if (widget.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              child: Text('Nothing unscheduled.', style: AppTextStyles.mono()),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: AppTextStyles.kicker()),
                Text(formatDuration(widget.total), style: AppTextStyles.kicker()),
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
            for (final entry in widget.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.goal!.name.toLowerCase(),
                        style: AppTextStyles.mono(
                          color: resolveCategory(
                            widget.categories,
                            entry.goal!.categoryId,
                          ).color,
                        ),
                      ),
                    ),
                    Text(
                      formatDuration(entry.duration),
                      style: AppTextStyles.mono(color: AppColors.text),
                    ),
                    if (widget.date != null) ...[
                      const SizedBox(width: AppSpacing.s2),
                      QuickLogCheckButton(
                        onTap: () => _quickLog(entry.goal!, entry.duration),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
