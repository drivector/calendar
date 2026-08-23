import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/utils/duration_format.dart';

void main() {
  group('formatDuration', () {
    test('hours and minutes', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 45)),
        '1 h 45',
      );
    });

    test('minutes only', () {
      expect(formatDuration(const Duration(minutes: 45)), '45 m');
    });

    test('whole hours only', () {
      expect(formatDuration(const Duration(hours: 8)), '8 h');
    });
  });

  group('formatSignedDuration', () {
    test('negative drift', () {
      expect(
        formatSignedDuration(const Duration(hours: -1, minutes: -15)),
        '−1 h 15',
      );
    });

    test('positive drift', () {
      expect(
        formatSignedDuration(const Duration(hours: 1, minutes: 15)),
        '+1 h 15',
      );
    });

    test('zero drift', () {
      expect(formatSignedDuration(Duration.zero), '—');
    });
  });
}
