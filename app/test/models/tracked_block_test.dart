import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/planned_block.dart';
import 'package:calendar_tracker/models/tracked_block.dart';

PlannedBlock _planned({
  required String id,
  required DateTime start,
  required DateTime end,
  String categoryId = 'walking',
}) => PlannedBlock(
  id: id,
  start: start,
  end: end,
  title: 'Plan',
  categoryId: categoryId,
);

TrackedBlock _tracked({
  required DateTime start,
  required DateTime end,
  String categoryId = 'walking',
  String? plannedBlockId,
}) => TrackedBlock(
  id: 'tracked-1',
  start: start,
  end: end,
  title: 'Actual',
  categoryId: categoryId,
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

    test('true when a planned block shares the category and overlaps the time range', () {
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

    test('false when the categories differ, even with identical time ranges', () {
      final planned = [
        _planned(
          id: 'plan-1',
          start: DateTime(2026, 8, 20, 16, 0),
          end: DateTime(2026, 8, 20, 16, 30),
          categoryId: 'deep-work',
        ),
      ];
      final tracked = _tracked(
        start: DateTime(2026, 8, 20, 16, 0),
        end: DateTime(2026, 8, 20, 16, 30),
      );

      expect(trackedBlockWasPlanned(tracked, planned), isFalse);
    });

    test('false when the same-category block does not overlap in time', () {
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
          categoryId: 'deep-work',
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
}
