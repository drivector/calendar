import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/week_day_summary.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../state/root_shell_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';
import 'week_day_bar.dart';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Tapping a day row opens that day in the Day view — the same way tapping
/// a day in a calendar app's week/month view always has.
class WeekDayRow extends ConsumerWidget {
  const WeekDayRow({super.key, required this.summary});

  final WeekDaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToday = _isSameDay(summary.date, DateTime.now());
    final drift = Duration(minutes: (summary.driftHours * 60).round());
    final categories = ref.watch(categoriesProvider);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(selectedDateProvider.notifier).state = summary.date;
        ref.read(currentTabIndexProvider.notifier).state = 0;
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isToday ? AppColors.text.withValues(alpha: 0.03) : null,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s2,
            horizontal: AppSpacing.s1,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  DateFormat('EEE d').format(summary.date).toUpperCase(),
                  style: AppTextStyles.mono(),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: WeekDayBar(summary: summary, categories: categories),
              ),
              const SizedBox(width: AppSpacing.s2),
              SizedBox(
                width: 32,
                child: Text(
                  formatSignedDuration(drift),
                  textAlign: TextAlign.right,
                  style: AppTextStyles.mono(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
