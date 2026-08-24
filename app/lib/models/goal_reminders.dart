import 'package:intl/intl.dart';

import 'goal.dart';
import 'goal_planned_blocks.dart';

/// One reminder to actually schedule with the OS — derived from a goal's
/// own schedule, the same way [generateGoalPlannedBlocksForDate] derives
/// calendar blocks. Nothing is stored: this is recomputed from the goals
/// list whenever it changes, so editing or deleting a goal (or its
/// reminder setting) is reflected on the next resync with no separate
/// cleanup step.
class ReminderOccurrence {
  const ReminderOccurrence({
    required this.id,
    required this.goalId,
    required this.title,
    required this.body,
    required this.scheduledTime,
  });

  /// Positive 32-bit id — the platform notification id needs to fit in a
  /// signed 32-bit int, so this is derived from the source block id via
  /// [String.hashCode] masked down rather than stored separately.
  final int id;
  final String goalId;
  final String title;
  final String body;
  final DateTime scheduledTime;
}

final _timeFormat = DateFormat('HH:mm');

/// Computes every reminder that should be scheduled right now: for each
/// goal with [Goal.reminderMinutesBefore] set, walks the next [windowDays]
/// days of its own generated planned blocks and offsets each one's start
/// time backwards by the lead time. Anything that would already be in the
/// past relative to [now] is dropped — there's nothing to schedule for it.
///
/// A rolling window rather than scheduling every occurrence up to a goal's
/// end date keeps this cheap to recompute on every goals change; callers
/// are expected to resync periodically (e.g. on app foreground) to keep
/// the window moving forward.
List<ReminderOccurrence> computeReminderOccurrences({
  required List<Goal> goals,
  required DateTime now,
  int windowDays = 14,
}) {
  final remindable = goals.where((g) => g.reminderMinutesBefore != null);
  if (remindable.isEmpty) return const [];

  final today = DateTime(now.year, now.month, now.day);
  final occurrences = <ReminderOccurrence>[];

  for (var offset = 0; offset < windowDays; offset++) {
    final day = today.add(Duration(days: offset));
    final blocks = generateGoalPlannedBlocksForDate(goals: remindable.toList(), date: day);

    for (final block in blocks) {
      final goal = remindable.firstWhere((g) => g.id == block.goalId);
      final scheduledTime = block.start.subtract(
        Duration(minutes: goal.reminderMinutesBefore!),
      );
      if (scheduledTime.isBefore(now)) continue;

      occurrences.add(
        ReminderOccurrence(
          id: block.id.hashCode & 0x7fffffff,
          goalId: goal.id,
          title: goal.name,
          body: 'Starts at ${_timeFormat.format(block.start)}',
          scheduledTime: scheduledTime,
        ),
      );
    }
  }

  return occurrences;
}
