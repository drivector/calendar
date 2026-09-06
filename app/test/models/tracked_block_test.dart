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

  group('hasNoTime', () {
    test('defaults to false', () {
      final tracked = _tracked(
        start: DateTime(2026, 8, 20, 16, 0),
        end: DateTime(2026, 8, 20, 16, 30),
      );

      expect(tracked.hasNoTime, isFalse);
    });

    test('round-trips through toMap/fromMap', () {
      final tracked = TrackedBlock(
        id: 'tracked-1',
        start: DateTime(2026, 8, 20, 12, 0),
        end: DateTime(2026, 8, 20, 12, 30),
        title: 'Piano',
        goalId: 'goal-piano',
        sourceId: 'manual',
        hasNoTime: true,
      );

      final restored = TrackedBlock.fromMap('tracked-1', tracked.toMap());

      expect(restored.hasNoTime, isTrue);
    });

    test(
      'a document written before this field existed reads back false, not '
      'a crash',
      () {
        final restored = TrackedBlock.fromMap('tracked-1', {
          'start': DateTime(2026, 8, 20, 12, 0).toIso8601String(),
          'end': DateTime(2026, 8, 20, 12, 30).toIso8601String(),
          'title': 'Piano',
          'goalId': 'goal-piano',
          'sourceId': 'manual',
        });

        expect(restored.hasNoTime, isFalse);
      },
    );

    test('copyWithStatus preserves hasNoTime', () {
      final tracked = TrackedBlock(
        id: 'tracked-1',
        start: DateTime(2026, 8, 20, 12, 0),
        end: DateTime(2026, 8, 20, 12, 30),
        title: 'Piano',
        goalId: 'goal-piano',
        sourceId: 'manual',
        hasNoTime: true,
      );

      final deleted = tracked.copyWithStatus(TrackedBlockStatus.deleted);

      expect(deleted.hasNoTime, isTrue);
    });
  });
}
