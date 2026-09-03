/// "1h 45m", "45m", "8h" — no sign, no space between a number and its unit
/// letter (only between the hour and minute parts, when both are shown).
String formatDuration(Duration duration) {
  final totalMinutes = duration.inMinutes.abs();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

/// "−1h 15m", "+1h 15m", "—" for zero — used in the drift footer.
String formatSignedDuration(Duration duration) {
  if (duration.inMinutes == 0) return '—';
  final sign = duration.isNegative ? '−' : '+';
  return '$sign${formatDuration(duration)}';
}

Duration hoursToDuration(double hours) =>
    Duration(minutes: (hours * 60).round());

/// [formatDuration] for a plain hours figure (e.g. a computed
/// `GoalProgress.actualHours`) — the "h m" format is the one duration
/// format used everywhere in this app; nothing should show decimal hours
/// like "12.4 h" instead.
String formatHours(double hours) => formatDuration(hoursToDuration(hours));

/// "12:34" (mm:ss) below an hour, "1:02:34" (h:mm:ss) once it runs long —
/// a live stopwatch reads seconds, unlike [formatDuration]'s "1h 45m" for
/// a completed duration. Shared by the live-activity header pill and its
/// own growing block on the calendar, so the two always read the same.
String formatElapsedClock(Duration elapsed) {
  final totalSeconds = elapsed.inSeconds.abs();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}
