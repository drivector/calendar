import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/drift.dart';
import 'package:calendar_tracker/models/planned_block.dart';
import 'package:calendar_tracker/models/tracked_block.dart';

void main() {
  final day = DateTime(2026, 8, 20);
  DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);

  test('drift is tracked minus planned, per category, signed', () {
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
    expect(drift.single.delta, const Duration(hours: -1, minutes: -15));
  });

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
}
