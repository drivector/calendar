import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/activity_log.dart';
import 'package:calendar_tracker/models/tracked_block.dart';

TrackedBlock _block({
  required String id,
  required DateTime start,
  int minutes = 30,
}) => TrackedBlock(
  id: id,
  start: start,
  end: start.add(Duration(minutes: minutes)),
  title: id,
  categoryId: 'walking',
  sourceId: 'manual',
);

void main() {
  group('groupTrackedBlocksByDay', () {
    test('empty input gives an empty list', () {
      expect(groupTrackedBlocksByDay(const []), isEmpty);
    });

    test('blocks on the same day land in one group', () {
      final blocks = [
        _block(id: 'a', start: DateTime(2026, 8, 20, 9, 0)),
        _block(id: 'b', start: DateTime(2026, 8, 20, 14, 0)),
      ];

      final groups = groupTrackedBlocksByDay(blocks);

      expect(groups, hasLength(1));
      expect(groups.single.day, DateTime(2026, 8, 20));
      expect(groups.single.blocks, hasLength(2));
    });

    test('groups are ordered most-recent-day first', () {
      final blocks = [
        _block(id: 'mon', start: DateTime(2026, 8, 17, 9, 0)),
        _block(id: 'wed', start: DateTime(2026, 8, 19, 9, 0)),
        _block(id: 'tue', start: DateTime(2026, 8, 18, 9, 0)),
      ];

      final groups = groupTrackedBlocksByDay(blocks);

      expect(groups.map((g) => g.day), [
        DateTime(2026, 8, 19),
        DateTime(2026, 8, 18),
        DateTime(2026, 8, 17),
      ]);
    });

    test(
      "within a day, blocks are in start-time order regardless of input order",
      () {
        final blocks = [
          _block(id: 'afternoon', start: DateTime(2026, 8, 20, 14, 0)),
          _block(id: 'morning', start: DateTime(2026, 8, 20, 7, 0)),
          _block(id: 'noon', start: DateTime(2026, 8, 20, 12, 0)),
        ];

        final groups = groupTrackedBlocksByDay(blocks);

        expect(groups.single.blocks.map((b) => b.id), [
          'morning',
          'noon',
          'afternoon',
        ]);
      },
    );
  });
}
