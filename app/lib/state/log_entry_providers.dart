import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The manual-entry form's working state — matches the README's
/// `draftLogEntry`.
class DraftLogEntry {
  const DraftLogEntry({
    this.date,
    this.activity = '',
    this.start,
    this.end,
    this.goalId,
    this.note = '',
  });

  /// Which day this entry is logged against — defaults to whatever day the
  /// app is currently showing when the sheet opens, but is the first thing
  /// the form asks about, so logging something for yesterday (or any other
  /// day) doesn't require leaving the sheet first to change the app's
  /// selected date.
  final DateTime? date;
  final String activity;
  final TimeOfDay? start;
  final TimeOfDay? end;

  /// The goal this activity counts toward — logging is goal-first, not
  /// category-first; the block's category is derived from the goal.
  final String? goalId;
  final String note;

  Duration? get duration {
    final start = this.start;
    final end = this.end;
    if (start == null || end == null) return null;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final delta = endMinutes - startMinutes;
    return Duration(minutes: delta < 0 ? delta + 24 * 60 : delta);
  }

  DraftLogEntry copyWith({
    DateTime? date,
    String? activity,
    TimeOfDay? start,
    TimeOfDay? end,
    String? goalId,
    String? note,
  }) {
    return DraftLogEntry(
      date: date ?? this.date,
      activity: activity ?? this.activity,
      start: start ?? this.start,
      end: end ?? this.end,
      goalId: goalId ?? this.goalId,
      note: note ?? this.note,
    );
  }
}

class DraftLogEntryNotifier extends StateNotifier<DraftLogEntry> {
  DraftLogEntryNotifier() : super(const DraftLogEntry());

  void setDate(DateTime value) => state = state.copyWith(date: value);
  void setActivity(String value) => state = state.copyWith(activity: value);
  void setStart(TimeOfDay value) => state = state.copyWith(start: value);
  void setEnd(TimeOfDay value) => state = state.copyWith(end: value);
  void setGoal(String goalId) => state = state.copyWith(goalId: goalId);
  void setNote(String value) => state = state.copyWith(note: value);
  void reset() => state = const DraftLogEntry();
}

final draftLogEntryProvider =
    StateNotifierProvider<DraftLogEntryNotifier, DraftLogEntry>(
      (ref) => DraftLogEntryNotifier(),
    );
