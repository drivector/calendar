import 'package:flutter/widgets.dart';

import '../../../models/category.dart';
import '../../../models/week_day_summary.dart';
import '../../../shared/widgets/dashed_border.dart';
import '../../../shared/widgets/hatch_pattern.dart';
import '../../../state/categories_providers.dart';
import '../../../theme/app_colors.dart';

/// Stacked plan (dashed, 8px) + actual (solid + hatch, 11px) bars, segment
/// widths proportional to each category's hours.
class WeekDayBar extends StatelessWidget {
  const WeekDayBar({
    super.key,
    required this.summary,
    required this.categories,
  });

  final WeekDaySummary summary;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 8,
          child: _segments(summary.plannedHoursByCategory, dashed: true),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 11,
          child: _segments(
            summary.actualHoursByCategory,
            dashed: false,
            untrackedHours: summary.untrackedHours,
          ),
        ),
      ],
    );
  }

  Widget _segments(
    Map<String, double> hoursByCategory, {
    required bool dashed,
    double untrackedHours = 0,
  }) {
    final entries = hoursByCategory.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty && untrackedHours <= 0) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        for (final entry in entries)
          Expanded(
            flex: (entry.value * 100).round().clamp(1, 1 << 30),
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: dashed
                  ? DashedRectBorder(
                      color: resolveCategory(categories, entry.key).color,
                      child: const SizedBox.expand(),
                    )
                  : SizedBox.expand(
                      child: ColoredBox(
                        color: resolveCategory(categories, entry.key).color,
                      ),
                    ),
            ),
          ),
        if (untrackedHours > 0)
          Expanded(
            flex: (untrackedHours * 100).round().clamp(1, 1 << 30),
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.ink(0.2)),
                ),
                child: const HatchPatternBox(),
              ),
            ),
          ),
      ],
    );
  }
}
