import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The manual-entry form's working state — matches the README's
/// `draftLogEntry`.
class DraftLogEntry {
  const DraftLogEntry({
    this.activity = '',
    this.start,
    this.end,
    this.categoryId,
    this.note = '',
  });

  final String activity;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final String? categoryId;
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
    String? activity,
    TimeOfDay? start,
    TimeOfDay? end,
    String? categoryId,
    String? note,
  }) {
    return DraftLogEntry(
      activity: activity ?? this.activity,
      start: start ?? this.start,
      end: end ?? this.end,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
    );
  }
}

class DraftLogEntryNotifier extends StateNotifier<DraftLogEntry> {
  DraftLogEntryNotifier() : super(const DraftLogEntry());

  void setActivity(String value) => state = state.copyWith(activity: value);
  void setStart(TimeOfDay value) => state = state.copyWith(start: value);
  void setEnd(TimeOfDay value) => state = state.copyWith(end: value);
  void setCategory(String categoryId) =>
      state = state.copyWith(categoryId: categoryId);
  void setNote(String value) => state = state.copyWith(note: value);
  void reset() => state = const DraftLogEntry();
}

final draftLogEntryProvider =
    StateNotifierProvider<DraftLogEntryNotifier, DraftLogEntry>(
  (ref) => DraftLogEntryNotifier(),
);
