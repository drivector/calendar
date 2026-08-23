import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/tracked_block.dart';
import 'package:calendar_tracker/models/untracked_gap.dart';

void main() {
  final day = DateTime(2026, 8, 20);
  DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);

  test('a gap at or above the threshold is reported', () {
    final gaps = computeUntrackedGaps(
      tracked: const [],
      windowStart: DateTime(2026, 8, 20, 12, 0),
      windowEnd: DateTime(2026, 8, 20, 13, 10),
      minDuration: const Duration(minutes: 45),
    );

    expect(gaps, hasLength(1));
    expect(gaps.single.duration, const Duration(hours: 1, minutes: 10));
  });

  test('a gap below the threshold is dropped', () {
    final gaps = computeUntrackedGaps(
      tracked: [
        TrackedBlock(
          id: 'a',
          start: at(9, 0),
          end: at(10, 45),
          title: 'Deep work',
          categoryId: 'deep_work',
          sourceId: 'jira',
        ),
        TrackedBlock(
          id: 'b',
          start: at(10, 45),
          end: at(11, 25),
          title: 'Call',
          categoryId: 'meetings',
          sourceId: 'calendar',
        ),
      ],
      windowStart: at(9, 0),
      windowEnd: at(12, 0),
      minDuration: const Duration(minutes: 45),
    );

    // The 35-minute leftover (11:25-12:00) is below the 45-minute threshold.
    expect(gaps, isEmpty);
  });

  test('gaps around tracked blocks are both reported when large enough', () {
    final gaps = computeUntrackedGaps(
      tracked: [
        TrackedBlock(
          id: 'a',
          start: at(9, 0),
          end: at(9, 30),
          title: 'Something',
          categoryId: 'admin',
          sourceId: 'manual',
        ),
      ],
      windowStart: at(8, 0),
      windowEnd: at(11, 0),
      minDuration: const Duration(minutes: 45),
    );

    expect(gaps, hasLength(2));
    expect(gaps[0].start, at(8, 0));
    expect(gaps[0].end, at(9, 0));
    expect(gaps[1].start, at(9, 30));
    expect(gaps[1].end, at(11, 0));
  });
}
