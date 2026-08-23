/// A time of day with no date attached — for goals scheduled against a
/// specific clock time (e.g. work 09:00–18:00), as opposed to a plain
/// duration with no fixed time (e.g. piano, 15 min, any time).
class ClockTime {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  /// This time minus [other], wrapping past midnight if this time is
  /// earlier in the day (e.g. an overnight shift 22:00–06:00 = 8h).
  Duration difference(ClockTime other) {
    final delta = minutesSinceMidnight - other.minutesSinceMidnight;
    return Duration(minutes: delta < 0 ? delta + 24 * 60 : delta);
  }

  String format() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class ClockRange {
  const ClockRange(this.start, this.end);

  final ClockTime start;
  final ClockTime end;

  Duration get duration => end.difference(start);
}
