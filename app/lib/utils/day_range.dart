/// Date-only / day-membership helpers, shared by the models and the
/// providers. These used to live in `state/day_view_providers.dart`, which
/// still re-exports them so every existing import keeps working — they
/// moved here so `models/tracked_block.dart` can use the *same*
/// overnight rule as the Day view rather than restating it.
library;

DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// [date] with its time-of-day stripped.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// [date]'s own [00:00, 24:00) span, as real `DateTime`s — the boundary
/// every overnight-block calculation clamps against.
(DateTime start, DateTime end) dayBounds(DateTime date) {
  final start = dateOnly(date);
  return (start, start.add(const Duration(days: 1)));
}

/// True if [start, end) overlaps [date]'s own day at all — unlike
/// [isSameDay], which only ever matches a block's own *start* date, this
/// is what an overnight block (started one evening, ending after
/// midnight) needs: it genuinely belongs to *both* days it touches, not
/// just the one it started on. A real gap a user hit directly — an
/// activity registered from Wednesday evening to Thursday 1:30am simply
/// never appeared anywhere on Thursday's own column.
bool overlapsDay(DateTime start, DateTime end, DateTime date) {
  final (dayStart, dayEnd) = dayBounds(date);
  return start.isBefore(dayEnd) && end.isAfter(dayStart);
}
