import 'package:flutter/material.dart' show TimeOfDay;

/// [time] plus [minutes], wrapping past midnight.
TimeOfDay addMinutes(TimeOfDay time, int minutes) {
  final total = (time.hour * 60 + time.minute + minutes) % (24 * 60);
  return TimeOfDay(hour: total ~/ 60, minute: total % 60);
}
