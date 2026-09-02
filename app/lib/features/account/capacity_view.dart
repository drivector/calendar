import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/category.dart';
import '../../models/day_capacity.dart';
import '../../models/goal_progress.dart';
import '../../shared/widgets/hatch_pattern.dart';
import '../../state/categories_providers.dart';
import '../../state/goals_providers.dart';
import '../../state/week_view_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/duration_format.dart';

/// "How much is planned, and how much is still available" — shows plan vs.
/// available time per day and per goal for the current week. Two sections:
/// free time slots per day (against the user's own tracking window, set on
/// the Account screen's Details tab — the same one the Day view uses for
/// "untracked"), and remaining room per goal (target minus what's already
/// planned toward it this week).
///
/// A body, not a screen: it's one of the Account screen's segments, so the
/// surrounding chrome (background, safe area, header) belongs to
/// [AccountScreen] rather than being repeated here.
class CapacityView extends ConsumerWidget {
  const CapacityView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(weekDayCapacityProvider);
    final goalProgressList = ref.watch(goalProgressListProvider);
    final categories = ref.watch(categoriesProvider);

    final totalPlanned = days.fold<double>(0, (t, d) => t + d.plannedHours);
    final totalAvailable = days.fold<double>(0, (t, d) => t + d.availableHours);
    final totalWindow = days.fold<double>(0, (t, d) => t + d.windowHours);

    return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Planned', style: AppTextStyles.kicker()),
                        Text('Available', style: AppTextStyles.kicker()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatHours(totalPlanned),
                          style: AppTextStyles.title().copyWith(fontSize: 24),
                        ),
                        Text(
                          '${formatHours(totalAvailable)} of '
                          '${formatHours(totalWindow)} this week',
                          style: AppTextStyles.mono(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text('FREE TIME PER DAY', style: AppTextStyles.kicker()),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'against each day\'s own tracking window — the same '
                      'one the Day view uses for "untracked". Change it from '
                      'Account · Details.',
                      style: AppTextStyles.mono(),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    for (final day in days)
                      _DayCapacityRow(day: day, categories: categories),
                    const SizedBox(height: AppSpacing.s4),
                    Text('ROOM TOWARD GOALS', style: AppTextStyles.kicker()),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'each goal\'s weekly target minus what\'s already planned',
                      style: AppTextStyles.mono(),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    if (goalProgressList.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s2,
                        ),
                        child: Text(
                          'No active goals this week.',
                          style: AppTextStyles.mono(),
                        ),
                      )
                    else
                      for (final progress in goalProgressList)
                        _GoalRoomRow(
                          progress: progress,
                          color: resolveCategory(
                            categories,
                            progress.goal.categoryId,
                          ).color,
                        ),
                  ],
                ),
              );
  }
}

class _DayCapacityRow extends StatelessWidget {
  const _DayCapacityRow({required this.day, required this.categories});

  final DayCapacity day;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final windowStart = day.windowStart;
    final windowEnd = day.windowEnd;
    final hasTimeline =
        windowStart != null &&
        windowEnd != null &&
        windowEnd.isAfter(windowStart);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              DateFormat('EEE d').format(day.date).toUpperCase(),
              style: AppTextStyles.mono(),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 14,
              child: hasTimeline
                  ? _TimelineBar(
                      day: day,
                      categories: categories,
                      windowStart: windowStart,
                      windowEnd: windowEnd,
                    )
                  : _StackedBar(day: day, categories: categories),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          SizedBox(
            width: 96,
            child: Text(
              day.overplannedHours > 0
                  ? 'over by ${formatHours(day.overplannedHours)}'
                  : '${formatHours(day.availableHours)} free',
              textAlign: TextAlign.right,
              style: AppTextStyles.mono(
                color: day.overplannedHours > 0 ? AppColors.accent : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays the day's own planned blocks out in real chronological order
/// against [windowStart]–[windowEnd], so e.g. a sleep block from 1am–8am
/// renders at the start of the bar rather than wherever its category
/// happened to land in a per-category stack. Plain-duration goal entries
/// (no real clock time) are packed in after the last timed block, since
/// there's no true position to give them.
class _TimelineBar extends StatelessWidget {
  const _TimelineBar({
    required this.day,
    required this.categories,
    required this.windowStart,
    required this.windowEnd,
  });

  final DayCapacity day;
  final List<Category> categories;
  final DateTime windowStart;
  final DateTime windowEnd;

  @override
  Widget build(BuildContext context) {
    final blocks = [...day.plannedBlocks]
      ..sort((a, b) => a.start.compareTo(b.start));

    final timedByCategory = <String, double>{};
    for (final b in blocks) {
      timedByCategory.update(
        b.categoryId,
        (h) => h + b.duration.inMinutes / 60,
        ifAbsent: () => b.duration.inMinutes / 60,
      );
    }
    final untimedByCategory = <String, double>{};
    for (final entry in day.plannedHoursByCategory.entries) {
      final leftover = entry.value - (timedByCategory[entry.key] ?? 0);
      if (leftover > 0.01) untimedByCategory[entry.key] = leftover;
    }

    Widget hatch(int minutes) =>
        Expanded(flex: minutes, child: const HatchPatternBox());
    Widget colored(int minutes, Color color) =>
        Expanded(flex: minutes, child: ColoredBox(color: color));

    final segments = <Widget>[];
    var cursor = windowStart;

    for (final block in blocks) {
      var start = block.start.isBefore(windowStart)
          ? windowStart
          : block.start;
      final end = block.end.isAfter(windowEnd) ? windowEnd : block.end;
      if (!end.isAfter(start)) continue;
      if (start.isBefore(cursor)) start = cursor;
      if (!end.isAfter(start)) continue;

      final gapMinutes = start.difference(cursor).inMinutes;
      if (gapMinutes > 0) segments.add(hatch(gapMinutes));

      final blockMinutes = end.difference(start).inMinutes;
      segments.add(
        colored(blockMinutes, resolveCategory(categories, block.categoryId).color),
      );
      cursor = end;
    }

    var remainingMinutes = windowEnd.difference(cursor).inMinutes;
    for (final entry in untimedByCategory.entries) {
      if (remainingMinutes <= 0) break;
      final minutes = (entry.value * 60).round().clamp(0, remainingMinutes);
      if (minutes <= 0) continue;
      segments.add(colored(minutes, resolveCategory(categories, entry.key).color));
      remainingMinutes -= minutes;
    }

    if (remainingMinutes > 0) segments.add(hatch(remainingMinutes));
    if (segments.isEmpty) return const SizedBox.shrink();

    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: segments);
  }
}

/// Fallback for a day with no tracking window at all — nothing to lay a
/// timeline against, so planned time is just shown as one stacked block per
/// category next to the available portion.
class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.day, required this.categories});

  final DayCapacity day;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final plannedFlex = (day.plannedHours * 100).round().clamp(0, 1 << 30);
    final availableFlex = (day.availableHours * 100).round().clamp(0, 1 << 30);
    final plannedEntries = day.plannedHoursByCategory.entries
        .where((e) => e.value > 0)
        .toList();

    if (plannedFlex == 0 && availableFlex == 0) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plannedFlex > 0)
          Expanded(
            flex: plannedFlex,
            child: plannedEntries.isEmpty
                ? ColoredBox(color: AppColors.text)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in plannedEntries)
                        Expanded(
                          flex: (entry.value * 100).round().clamp(1, 1 << 30),
                          child: ColoredBox(
                            color: resolveCategory(categories, entry.key).color,
                          ),
                        ),
                    ],
                  ),
          ),
        if (plannedFlex > 0 && availableFlex > 0) const SizedBox(width: 2),
        if (availableFlex > 0)
          Expanded(flex: availableFlex, child: const HatchPatternBox()),
      ],
    );
  }
}

class _GoalRoomRow extends StatelessWidget {
  const _GoalRoomRow({required this.progress, required this.color});

  final GoalProgress progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final target = progress.goal.weeklyTargetHours;
    final available = (target - progress.plannedHours).clamp(
      0.0,
      target == 0 ? 0.0 : double.infinity,
    );
    final over = progress.plannedHours > target
        ? progress.plannedHours - target
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
      child: Row(
        children: [
          Container(width: 8, height: 8, color: color),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              '${progress.goal.name} · planned ${formatHours(progress.plannedHours)} '
              '/ ${formatHours(target)}',
              style: AppTextStyles.label(),
            ),
          ),
          Text(
            over > 0
                ? 'over by ${formatHours(over)}'
                : '${formatHours(available)} room',
            style: AppTextStyles.mono(
              color: over > 0 ? AppColors.accent : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
