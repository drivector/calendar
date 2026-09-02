import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/drift.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/planned_block.dart';
import 'package:calendar_tracker/models/tracked_block.dart';

void main() {
  final day = DateTime(2026, 8, 20);
  DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);

  Goal goal({required String id, required String categoryId}) => Goal(
    id: id,
    name: id,
    categoryId: categoryId,
    startDate: DateTime(2020, 1, 1),
    endDate: DateTime(2099, 12, 31),
    scheduleByWeekday: const {},
  );

  test(
    'with no goals, drift is tracked minus planned per category, signed — '
    'a category backed by no goal at all falls back to its own row',
    () {
      final planned = [
        PlannedBlock(
          id: 'p1',
          start: at(9, 0),
          end: at(12, 0),
          title: 'Deep work 3 h',
          categoryId: 'deep_work',
        ),
      ];
      final tracked = [
        TrackedBlock(
          id: 't1',
          start: at(9, 0),
          end: at(10, 45),
          title: 'Deep work 1 h 45',
          categoryId: 'deep_work',
          sourceId: 'jira',
        ),
      ];

      final drift = computeDrift(planned: planned, tracked: tracked);

      expect(drift, hasLength(1));
      expect(drift.single.categoryId, 'deep_work');
      expect(drift.single.goalId, isNull);
      expect(drift.single.delta, const Duration(hours: -1, minutes: -15));
    },
  );

  test('a category with only tracked time yields positive drift', () {
    final tracked = [
      TrackedBlock(
        id: 't1',
        start: at(10, 45),
        end: at(11, 25),
        title: 'Unplanned call 40 m',
        categoryId: 'meetings',
        sourceId: 'calendar',
      ),
    ];

    final drift = computeDrift(planned: const [], tracked: tracked);

    expect(drift.single.categoryId, 'meetings');
    expect(drift.single.delta, const Duration(minutes: 40));
  });

  test(
    'untimedPlannedByGoal counts even with no block and no tracked time — '
    'a goal that has never been logged still shows as behind',
    () {
      final piano = goal(id: 'goal-piano', categoryId: 'piano');
      final drift = computeDrift(
        planned: const [],
        tracked: const [],
        goals: [piano],
        untimedPlannedByGoal: const {'goal-piano': Duration(minutes: 15)},
      );

      expect(drift.single.goalId, 'goal-piano');
      expect(drift.single.categoryId, 'piano');
      expect(drift.single.delta, const Duration(minutes: -15));
    },
  );

  test('untimedPlannedByGoal adds on top of a block-based planned total', () {
    final work = goal(id: 'goal-work', categoryId: 'work');
    final planned = [
      PlannedBlock(
        id: 'p1',
        start: at(9, 0),
        end: at(12, 0),
        title: 'Work 3 h',
        categoryId: 'work',
      ),
    ];
    final tracked = [
      TrackedBlock(
        id: 't1',
        start: at(9, 0),
        end: at(12, 0),
        title: 'Work 3 h',
        categoryId: 'work',
        sourceId: 'manual',
      ),
    ];

    final drift = computeDrift(
      planned: planned,
      tracked: tracked,
      goals: [work],
      untimedPlannedByGoal: const {'goal-work': Duration(minutes: 30)},
    );

    // The 3h block is fully covered by tracked time, but the extra 30m of
    // untimed planned duration for the same category still isn't.
    expect(drift.single.goalId, 'goal-work');
    expect(drift.single.delta, const Duration(minutes: -30));
  });

  test(
    'two goals sharing a category get separate drift rows, not one merged '
    "row — the exact bug a real user hit with two goals ('job' and a "
    "'side project') both under 'work'",
    () {
      final job = goal(id: 'goal-job', categoryId: 'work');
      final sideProject = goal(id: 'goal-side-project', categoryId: 'work');

      // A goal-generated block carries its own goal id directly, so it's
      // never ambiguous which goal it belongs to.
      final planned = [
        PlannedBlock(
          id: 'p-job',
          start: at(9, 0),
          end: at(11, 0),
          title: 'Job',
          categoryId: 'work',
          goalId: 'goal-job',
        ),
        PlannedBlock(
          id: 'p-side-project',
          start: at(20, 0),
          end: at(20, 30),
          title: 'Side project',
          categoryId: 'work',
          goalId: 'goal-side-project',
        ),
      ];
      // A manually logged block only ever carries a category — it's
      // resolved to whichever goal `goals` first matches that category to
      // ('job', first in the list), never split across both.
      final tracked = [
        TrackedBlock(
          id: 't-work',
          start: at(9, 0),
          end: at(10, 0),
          title: 'Some work',
          categoryId: 'work',
          sourceId: 'manual',
        ),
      ];

      final drift = computeDrift(
        planned: planned,
        tracked: tracked,
        goals: [job, sideProject],
      );

      // Two rows, not one merged "work" row.
      expect(drift, hasLength(2));
      final byGoal = {for (final d in drift) d.goalId: d.delta};
      // job: 1h tracked against its own 2h planned block.
      expect(byGoal['goal-job'], const Duration(hours: -1));
      // side project: nothing tracked against it — the manual block's hour
      // landed entirely on "job", not split or duplicated onto both goals.
      expect(byGoal['goal-side-project'], const Duration(minutes: -30));
    },
  );
}
