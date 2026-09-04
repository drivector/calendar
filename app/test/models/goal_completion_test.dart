import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/goal_completion.dart';
import 'package:calendar_tracker/models/planned_block.dart';
import 'package:calendar_tracker/models/tracked_block.dart';

final _ongoingStart = DateTime(2020, 1, 1);
final _ongoingEnd = DateTime(2099, 12, 31);
final _weekStart = DateTime(2026, 8, 17); // a Monday
// Safely after every block these tests construct (including the one
// deliberately placed a week later) — "complete" only fills in the past.
final _now = DateTime(2026, 9, 1, 12, 0);

Goal _goal({String id = 'goal-walking', String categoryId = 'walking'}) => Goal(
  id: id,
  name: 'Walking',
  categoryId: categoryId,
  startDate: _ongoingStart,
  endDate: _ongoingEnd,
  scheduleByWeekday: {
    for (var weekday = 1; weekday <= 7; weekday++)
      weekday: [const DayScheduleEntry.duration(Duration(minutes: 30))],
  },
);

PlannedBlock _plannedBlock({
  required String id,
  required DateTime start,
  String goalId = 'goal-walking',
}) => PlannedBlock(
  id: id,
  start: start,
  end: start.add(const Duration(minutes: 30)),
  title: 'Walk',
  goalId: goalId,
);

void main() {
  group('pendingPlannedBlocksForGoal', () {
    test('a manual planned block belonging to the goal, in-week, with no tracked block is pending', () {
      final goal = _goal();
      final planned = [
        _plannedBlock(
          id: 'plan-1',
          start: _weekStart.add(const Duration(hours: 8)),
        ),
      ];

      final pending = pendingPlannedBlocksForGoal(
        goal: goal,
        allPlanned: planned,
        generatedThisWeek: const [],
        allTracked: const [],
        weekStart: _weekStart,
        now: _now,
      );

      expect(pending, hasLength(1));
      expect(pending.single.id, 'plan-1');
    });

    test(
      'a planned block already covered by a tracked block is not pending',
      () {
        final goal = _goal();
        final planned = [
          _plannedBlock(
            id: 'plan-1',
            start: _weekStart.add(const Duration(hours: 8)),
          ),
        ];
        final tracked = [
          TrackedBlock(
            id: 'complete-plan-1',
            start: _weekStart.add(const Duration(hours: 8)),
            end: _weekStart.add(const Duration(hours: 8, minutes: 30)),
            title: 'Walk',
            goalId: 'goal-walking',
            sourceId: 'manual',
            plannedBlockId: 'plan-1',
          ),
        ];

        final pending = pendingPlannedBlocksForGoal(
          goal: goal,
          allPlanned: planned,
          generatedThisWeek: const [],
          allTracked: tracked,
          weekStart: _weekStart,
          now: _now,
        );

        expect(pending, isEmpty);
      },
    );

    test(
      'a goal-generated block for this goal, not yet tracked, is pending',
      () {
        final goal = _goal();
        final generated = [
          _plannedBlock(
            id: 'goal-goal-walking-2026-08-18-0',
            start: _weekStart.add(const Duration(days: 1, hours: 7)),
            goalId: 'goal-walking',
          ),
        ];

        final pending = pendingPlannedBlocksForGoal(
          goal: goal,
          allPlanned: const [],
          generatedThisWeek: generated,
          allTracked: const [],
          weekStart: _weekStart,
          now: _now,
        );

        expect(pending, hasLength(1));
      },
    );

    test('a generated block belonging to a different goal is not pending', () {
      final goal = _goal();
      final generated = [
        _plannedBlock(
          id: 'goal-other-2026-08-18-0',
          start: _weekStart.add(const Duration(days: 1, hours: 7)),
          goalId: 'goal-other',
        ),
      ];

      final pending = pendingPlannedBlocksForGoal(
        goal: goal,
        allPlanned: const [],
        generatedThisWeek: generated,
        allTracked: const [],
        weekStart: _weekStart,
        now: _now,
      );

      expect(pending, isEmpty);
    });

    test('a planned block outside the given week is not pending', () {
      final goal = _goal();
      final planned = [
        _plannedBlock(
          id: 'plan-next-week',
          start: _weekStart.add(const Duration(days: 8, hours: 8)),
        ),
      ];

      final pending = pendingPlannedBlocksForGoal(
        goal: goal,
        allPlanned: planned,
        generatedThisWeek: const [],
        allTracked: const [],
        weekStart: _weekStart,
        now: _now,
      );

      expect(pending, isEmpty);
    });

    test('a planned block belonging to a different goal is not pending', () {
      final goal = _goal();
      final planned = [
        _plannedBlock(
          id: 'plan-1',
          start: _weekStart.add(const Duration(hours: 8)),
          goalId: 'goal-deep-work',
        ),
      ];

      final pending = pendingPlannedBlocksForGoal(
        goal: goal,
        allPlanned: planned,
        generatedThisWeek: const [],
        allTracked: const [],
        weekStart: _weekStart,
        now: _now,
      );

      expect(pending, isEmpty);
    });

    test('a planned block that has not ended yet is not pending', () {
      final goal = _goal();
      final planned = [
        _plannedBlock(id: 'plan-future', start: _now.add(const Duration(hours: 1))),
      ];

      final pending = pendingPlannedBlocksForGoal(
        goal: goal,
        allPlanned: planned,
        generatedThisWeek: const [],
        allTracked: const [],
        weekStart: DateTime(_now.year, _now.month, _now.day),
        now: _now,
      );

      expect(pending, isEmpty);
    });

    test('a planned block that ended just before now is pending', () {
      final goal = _goal();
      final planned = [
        _plannedBlock(
          id: 'plan-just-past',
          start: _now.subtract(const Duration(minutes: 45)),
        ),
      ];

      final pending = pendingPlannedBlocksForGoal(
        goal: goal,
        allPlanned: planned,
        generatedThisWeek: const [],
        allTracked: const [],
        weekStart: DateTime(_now.year, _now.month, _now.day),
        now: _now,
      );

      expect(pending, hasLength(1));
      expect(pending.single.id, 'plan-just-past');
    });
  });

  group('trackedBlocksCompletingPlan', () {
    test('builds one tracked block per pending block, mirroring its time/title/category', () {
      final pending = [
        _plannedBlock(
          id: 'plan-1',
          start: _weekStart.add(const Duration(hours: 8)),
        ),
      ];

      final built = trackedBlocksCompletingPlan(pending);

      expect(built, hasLength(1));
      final block = built.single;
      expect(block.start, pending.single.start);
      expect(block.end, pending.single.end);
      expect(block.title, pending.single.title);
      expect(block.goalId, pending.single.goalId);
      expect(block.plannedBlockId, 'plan-1');
      expect(block.sourceId, 'auto');
    });

    test('the id is derived from the planned block id, not a timestamp — idempotent on repeat', () {
      final pending = [
        _plannedBlock(
          id: 'plan-1',
          start: _weekStart.add(const Duration(hours: 8)),
        ),
      ];

      final first = trackedBlocksCompletingPlan(pending).single.id;
      final second = trackedBlocksCompletingPlan(pending).single.id;

      expect(first, second);
    });
  });
}
