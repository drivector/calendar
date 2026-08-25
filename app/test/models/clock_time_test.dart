import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/models/clock_time.dart';

void main() {
  group('ClockTime.difference', () {
    test('same-day range returns the plain minute delta', () {
      final start = ClockTime(9, 0);
      final end = ClockTime(17, 30);

      expect(end.difference(start), const Duration(hours: 8, minutes: 30));
    });

    test('wraps past midnight when end is earlier in the day than start', () {
      final start = ClockTime(22, 0);
      final end = ClockTime(6, 0);

      expect(end.difference(start), const Duration(hours: 8));
    });
  });

  group('isOvernightRange', () {
    test('false for a normal same-day range', () {
      expect(isOvernightRange(ClockTime(9, 0), ClockTime(17, 0)), isFalse);
    });

    test('true when end is before start', () {
      expect(isOvernightRange(ClockTime(14, 0), ClockTime(10, 0)), isTrue);
    });

    test('true when end exactly equals start (zero-length, not a range)', () {
      expect(isOvernightRange(ClockTime(9, 0), ClockTime(9, 0)), isTrue);
    });

    test('false when end is one minute after start', () {
      expect(isOvernightRange(ClockTime(9, 0), ClockTime(9, 1)), isFalse);
    });
  });
}
