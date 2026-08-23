/// "1 h 45", "45 m", "8 h" — no sign.
String formatDuration(Duration duration) {
  final totalMinutes = duration.inMinutes.abs();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours == 0) return '$minutes m';
  if (minutes == 0) return '$hours h';
  return '$hours h $minutes';
}

/// "−1 h 15", "+1 h 15", "—" for zero — used in the drift footer.
String formatSignedDuration(Duration duration) {
  if (duration.inMinutes == 0) return '—';
  final sign = duration.isNegative ? '−' : '+';
  return '$sign${formatDuration(duration)}';
}
