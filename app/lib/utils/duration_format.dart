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
