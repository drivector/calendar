import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/utils/time_of_day_utils.dart';

void main() {
  group('addMinutes', () {
    test('adds minutes within the same day', () {
      expect(
        addMinutes(const TimeOfDay(hour: 10, minute: 0), 30),
        const TimeOfDay(hour: 10, minute: 30),
      );
    });

    test(
      'a goal time-range entry suggests its end as 30 minutes after the start',
      () {
        // The exact case goal_edit_sheet.dart and add_block_sheet.dart rely
        // on: picking a start time should suggest a half-hour block, not a
        // fixed clock time unrelated to it.
        expect(
          addMinutes(const TimeOfDay(hour: 14, minute: 45), 30),
          const TimeOfDay(hour: 15, minute: 15),
        );
      },
    );

    test('wraps past midnight', () {
      expect(
        addMinutes(const TimeOfDay(hour: 23, minute: 45), 30),
        const TimeOfDay(hour: 0, minute: 15),
      );
    });
  });
}
