import 'clock_time.dart';

/// The full day — the default tracking window for any weekday with no
/// entries of its own, and the practical way to represent "no restriction"
/// without a separate always/sometimes flag. `ClockTime(24, 0)` as an end
/// is a valid sentinel: `DateTime(y, m, d, 24, 0)` rolls over to the next
/// day's midnight (Dart's own `DateTime` constructor normalizes it), so it
/// correctly spans the whole day rather than landing on it twice.
const fullDayWindow = ClockRange(ClockTime(0, 0), ClockTime(24, 0));

/// Which hours of the day count as "trackable" — feeds the Capacity page's
/// planned-vs-available breakdown and the untracked-gap calculation (see
/// `dayWindowFor` in `state/derived_providers.dart`), both of which used to
/// hardcode a single 07:00–18:00 window for every day alike. Per-weekday
/// now, and each day can hold more than one range (e.g. 06:00–09:00 and
/// 17:00–22:00, skipping a midday gap) — same shape as a goal's own
/// `scheduleByWeekday`, just [ClockRange] entries only (a tracking window
/// is inherently a clock range; there's no "duration, any time" version of
/// it the way a goal schedule entry can be). A weekday with no entries of
/// its own defaults to [fullDayWindow], so an account that's never touched
/// this setting tracks the full 24 hours, not a narrower default someone
/// has to discover and change.
class UserSettings {
  const UserSettings({
    this.trackingWindowsByWeekday = const {},
    this.defaultOpenHour = 18,
  });

  /// Keyed by [DateTime.weekday] (Monday = 1 .. Sunday = 7). A day with no
  /// key at all — not an empty list, which would mean "never trackable" —
  /// falls back to [fullDayWindow] via [windowsForWeekday].
  final Map<int, List<ClockRange>> trackingWindowsByWeekday;

  /// Which hour (0-23) the Day/Week timeline scrolls to when it first
  /// opens — the Calendar tab's own anchor, unrelated to the tracking
  /// window above. Defaults to 18 (6pm), the same fixed anchor the app
  /// used before this was configurable.
  final int defaultOpenHour;

  List<ClockRange> windowsForWeekday(int weekday) =>
      trackingWindowsByWeekday[weekday] ?? const [fullDayWindow];

  UserSettings copyWithWeekday(int weekday, List<ClockRange> windows) {
    return UserSettings(
      trackingWindowsByWeekday: {
        ...trackingWindowsByWeekday,
        weekday: windows,
      },
      defaultOpenHour: defaultOpenHour,
    );
  }

  UserSettings copyWithDefaultOpenHour(int hour) {
    return UserSettings(
      trackingWindowsByWeekday: trackingWindowsByWeekday,
      defaultOpenHour: hour,
    );
  }

  Map<String, dynamic> toMap() => {
    for (final entry in trackingWindowsByWeekday.entries)
      '${entry.key}': [
        for (final range in entry.value)
          {
            'startMinutes': range.start.minutesSinceMidnight,
            'endMinutes': range.end.minutesSinceMidnight,
          },
      ],
    'defaultOpenHour': defaultOpenHour,
  };

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      trackingWindowsByWeekday: {
        // Weekday windows are keyed by their numeric weekday, so skip the
        // non-numeric `defaultOpenHour` key sharing this same map.
        for (final entry in map.entries)
          if (int.tryParse(entry.key) != null)
            int.parse(entry.key): [
              for (final raw in entry.value as List<dynamic>)
                ClockRange(
                  ClockTime(
                    (raw['startMinutes'] as int) ~/ 60,
                    (raw['startMinutes'] as int) % 60,
                  ),
                  ClockTime(
                    (raw['endMinutes'] as int) ~/ 60,
                    (raw['endMinutes'] as int) % 60,
                  ),
                ),
            ],
      },
      defaultOpenHour: map['defaultOpenHour'] as int? ?? 18,
    );
  }
}
