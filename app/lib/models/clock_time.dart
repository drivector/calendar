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

/// Whether [end] is not after [start] — i.e. treating it as the end of a
/// same-day range would only work by wrapping into the next day (matching
/// [ClockTime.difference]'s own wrap-around). A Day-view block or a
/// logged activity can legitimately span midnight (a night shift), but a
/// goal's own schedule entry isn't expected to — see `GoalEditSheet`'s
/// overnight-confirmation prompt, which uses this to decide when to ask
/// before silently accepting one.
bool isOvernightRange(ClockTime start, ClockTime end) =>
    end.minutesSinceMidnight <= start.minutesSinceMidnight;
