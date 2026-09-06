import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/planned_block.dart';
import 'package:calendar_tracker/models/tracked_block.dart';

PlannedBlock _planned({
  required String id,
  required DateTime start,
  required DateTime end,
  String goalId = 'goal-walking',
}) => PlannedBlock(id: id, start: start, end: end, title: 'Plan', goalId: goalId);

TrackedBlock _tracked({
  required DateTime start,
  required DateTime end,
  String goalId = 'goal-walking',
  String? plannedBlockId,
}) => TrackedBlock(
  id: 'tracked-1',
  start: start,
  end: end,
  title: 'Actual',
  goalId: goalId,
  sourceId: 'manual',
  plannedBlockId: plannedBlockId,
);

void main() {
  group('trackedBlockWasPlanned', () {
    test('true when plannedBlockId is set, even with no overlapping planned block', () {
      final tracked = _tracked(
        start: DateTime(2026, 8, 20, 10, 0),
        end: DateTime(2026, 8, 20, 10, 30),
        plannedBlockId: 'plan-x',
      );

      expect(trackedBlockWasPlanned(tracked, const []), isTrue);
    });

    test('true when a planned block shares the goal and overlaps the time range', () {
      final planned = [
        _planned(
          id: 'plan-1',
          start: DateTime(2026, 8, 20, 16, 0),
          end: DateTime(2026, 8, 20, 16, 30),
        ),
      ];
      final tracked = _tracked(
        start: DateTime(2026, 8, 20, 16, 5),
        end: DateTime(2026, 8, 20, 16, 25),
      );

      expect(trackedBlockWasPlanned(tracked, planned), isTrue);
    });

    test('false when the goals differ, even with identical time ranges', () {
      final planned = [
        _planned(
          id: 'plan-1',
          start: DateTime(2026, 8, 20, 16, 0),
          end: DateTime(2026, 8, 20, 16, 30),
          goalId: 'goal-deep-work',
        ),
      ];
      final tracked = _tracked(
        start: DateTime(2026, 8, 20, 16, 0),
        end: DateTime(2026, 8, 20, 16, 30),
      );

      expect(trackedBlockWasPlanned(tracked, planned), isFalse);
    });

    test('false when the same-goal block does not overlap in time', () {
      final planned = [
        _planned(
          id: 'plan-1',
          start: DateTime(2026, 8, 20, 16, 0),
          end: DateTime(2026, 8, 20, 16, 30),
        ),
      ];
      final tracked = _tracked(
        start: DateTime(2026, 8, 20, 18, 0),
        end: DateTime(2026, 8, 20, 18, 30),
      );

      expect(trackedBlockWasPlanned(tracked, planned), isFalse);
    });

    test('false when a planned block merely touches the tracked block\'s boundary', () {
      // Planned ends exactly when tracked starts — adjacent, not overlapping.
      final planned = [
        _planned(
          id: 'plan-1',
          start: DateTime(2026, 8, 20, 15, 30),
          end: DateTime(2026, 8, 20, 16, 0),
        ),
      ];
      final tracked = _tracked(
        start: DateTime(2026, 8, 20, 16, 0),
        end: DateTime(2026, 8, 20, 16, 30),
      );

      expect(trackedBlockWasPlanned(tracked, planned), isFalse);
    });

    test('true when only one of several planned blocks actually overlaps', () {
      final planned = [
        _planned(
          id: 'plan-morning',
          start: DateTime(2026, 8, 20, 7, 0),
          end: DateTime(2026, 8, 20, 7, 30),
        ),
        _planned(
          id: 'plan-afternoon',
          start: DateTime(2026, 8, 20, 16, 0),
          end: DateTime(2026, 8, 20, 16, 30),
        ),
        _planned(
          id: 'plan-other-category',
          start: DateTime(2026, 8, 20, 16, 0),
          end: DateTime(2026, 8, 20, 16, 30),
          goalId: 'goal-deep-work',
        ),
      ];
      final tracked = _tracked(
        start: DateTime(2026, 8, 20, 16, 10),
        end: DateTime(2026, 8, 20, 16, 20),
      );

      expect(trackedBlockWasPlanned(tracked, planned), isTrue);
    });

    test('false with an empty planned list and no plannedBlockId', () {
      final tracked = _tracked(
        start: DateTime(2026, 8, 20, 16, 0),
        end: DateTime(2026, 8, 20, 16, 30),
      );

      expect(trackedBlockWasPlanned(tracked, const []), isFalse);
    });
  });

  group('untimed blocks', () {
    test('a timed block has a real clock position', () {
      final tracked = _tracked(
        start: DateTime(2026, 8, 20, 16, 0),
        end: DateTime(2026, 8, 20, 16, 30),
      );

      expect(tracked.isTimed, isTrue);
      expect(tracked.start, DateTime(2026, 8, 20, 16, 0));
      expect(tracked.end, DateTime(2026, 8, 20, 16, 30));
      expect(tracked.day, DateTime(2026, 8, 20));
      expect(tracked.duration, const Duration(minutes: 30));
    });

    test('an untimed block has none at all', () {
      final tracked = TrackedBlock.untimed(
        id: 'tracked-1',
        day: DateTime(2026, 8, 20),
        duration: const Duration(minutes: 15),
        title: 'Piano',
        goalId: 'goal-piano',
        sourceId: 'manual',
      );

      expect(tracked.isTimed, isFalse);
      expect(tracked.start, isNull);
      expect(tracked.end, isNull);
      expect(tracked.day, DateTime(2026, 8, 20));
      expect(tracked.duration, const Duration(minutes: 15));
    });

    test('an untimed block is never matched to a plan by overlap', () {
      // The old fabricated span ended at noon, so a plan covering midday
      // for the same goal silently claimed the block.
      final tracked = TrackedBlock.untimed(
        id: 'tracked-1',
        day: DateTime(2026, 8, 20),
        duration: const Duration(minutes: 15),
        title: 'Piano',
        goalId: 'goal-piano',
        sourceId: 'manual',
      );
      final planned = PlannedBlock(
        id: 'plan-1',
        start: DateTime(2026, 8, 20, 11, 0),
        end: DateTime(2026, 8, 20, 13, 0),
        title: 'Piano',
        goalId: 'goal-piano',
      );

      expect(matchingPlannedBlockFor(tracked, [planned]), isNull);
      expect(trackedBlockWasPlanned(tracked, [planned]), isFalse);
    });

    test('a day is credited from `day`, however long the duration', () {
      // The old form anchored the span at noon and counted backwards, so
      // anything over 12 hours started on the previous day and was
      // credited to it as well.
      final tracked = TrackedBlock.untimed(
        id: 'tracked-1',
        day: DateTime(2026, 8, 20),
        duration: const Duration(hours: 14),
        title: 'Piano',
        goalId: 'goal-piano',
        sourceId: 'manual',
      );

      expect(tracked.occursOn(DateTime(2026, 8, 20)), isTrue);
      expect(tracked.occursOn(DateTime(2026, 8, 19)), isFalse);
    });

    test('a timed overnight block occurs on both days it touches', () {
      final tracked = _tracked(
        start: DateTime(2026, 8, 20, 22, 0),
        end: DateTime(2026, 8, 21, 1, 30),
      );

      expect(tracked.occursOn(DateTime(2026, 8, 20)), isTrue);
      expect(tracked.occursOn(DateTime(2026, 8, 21)), isTrue);
      expect(tracked.day, DateTime(2026, 8, 20));
    });

    test('round-trips through toMap/fromMap', () {
      final tracked = TrackedBlock.untimed(
        id: 'tracked-1',
        day: DateTime(2026, 8, 20),
        duration: const Duration(minutes: 15),
        title: 'Piano',
        goalId: 'goal-piano',
        sourceId: 'manual',
      );

      final restored = TrackedBlock.fromMap('tracked-1', tracked.toMap());

      expect(restored.isTimed, isFalse);
      expect(restored.day, DateTime(2026, 8, 20));
      expect(restored.duration, const Duration(minutes: 15));
    });

    test('copyWithStatus preserves the untimed shape', () {
      final tracked = TrackedBlock.untimed(
        id: 'tracked-1',
        day: DateTime(2026, 8, 20),
        duration: const Duration(minutes: 15),
        title: 'Piano',
        goalId: 'goal-piano',
        sourceId: 'manual',
      );

      final deleted = tracked.copyWithStatus(TrackedBlockStatus.deleted);

      expect(deleted.isTimed, isFalse);
      expect(deleted.day, DateTime(2026, 8, 20));
      expect(deleted.duration, const Duration(minutes: 15));
      expect(deleted.status, TrackedBlockStatus.deleted);
    });
  });

  group('reading documents written by the previous schema', () {
    test('a start/end document reads back as a timed block', () {
      final restored = TrackedBlock.fromMap('tracked-1', {
        'start': DateTime(2026, 8, 20, 12, 0).toIso8601String(),
        'end': DateTime(2026, 8, 20, 12, 30).toIso8601String(),
        'title': 'Piano',
        'goalId': 'goal-piano',
        'sourceId': 'manual',
      });

      expect(restored.isTimed, isTrue);
      expect(restored.start, DateTime(2026, 8, 20, 12, 0));
      expect(restored.end, DateTime(2026, 8, 20, 12, 30));
      expect(restored.day, DateTime(2026, 8, 20));
      expect(restored.duration, const Duration(minutes: 30));
    });

    test('a hasNoTime document reads back as an untimed block', () {
      // The placeholder span these carried: 15 minutes ending at noon.
      final restored = TrackedBlock.fromMap('tracked-1', {
        'start': DateTime(2026, 8, 20, 11, 45).toIso8601String(),
        'end': DateTime(2026, 8, 20, 12, 0).toIso8601String(),
        'title': 'Piano',
        'goalId': 'goal-piano',
        'sourceId': 'manual',
        'hasNoTime': true,
      });

      expect(restored.isTimed, isFalse);
      expect(restored.start, isNull);
      expect(restored.day, DateTime(2026, 8, 20));
      expect(restored.duration, const Duration(minutes: 15));
    });

    test(
      "a hasNoTime document over 12 hours is credited to its `end`'s day, "
      'not the day its placeholder span started on',
      () {
        final restored = TrackedBlock.fromMap('tracked-1', {
          'start': DateTime(2026, 8, 19, 22, 0).toIso8601String(),
          'end': DateTime(2026, 8, 20, 12, 0).toIso8601String(),
          'title': 'Piano',
          'goalId': 'goal-piano',
          'sourceId': 'manual',
          'hasNoTime': true,
        });

        expect(restored.day, DateTime(2026, 8, 20));
        expect(restored.duration, const Duration(hours: 14));
      },
    );
  });
}
