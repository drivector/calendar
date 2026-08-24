import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/utils/duration_format.dart';

void main() {
  group('formatDuration', () {
    test('hours and minutes', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 45)), '1h 45m');
    });

    test('minutes only', () {
      expect(formatDuration(const Duration(minutes: 45)), '45m');
    });

    test('whole hours only', () {
      expect(formatDuration(const Duration(hours: 8)), '8h');
    });
  });

  group('formatSignedDuration', () {
    test('negative drift', () {
      expect(
        formatSignedDuration(const Duration(hours: -1, minutes: -15)),
        '−1h 15m',
      );
    });

    test('positive drift', () {
      expect(
        formatSignedDuration(const Duration(hours: 1, minutes: 15)),
        '+1h 15m',
      );
    });

    test('zero drift', () {
      expect(formatSignedDuration(Duration.zero), '—');
    });
  });

  group('formatHours', () {
    test('a fractional hours figure reads as "h m", never decimal', () {
      // The exact bug reported: "12.4 h" should never appear anywhere —
      // every hours figure in the app should go through this instead.
      expect(formatHours(12.4), '12h 24m');
    });

    test('a whole number of hours has no minutes suffix', () {
      expect(formatHours(4), '4h');
    });

    test('less than an hour has no hours prefix', () {
      expect(formatHours(0.5), '30m');
    });

    test('zero hours', () {
      expect(formatHours(0), '0m');
    });
  });
}
