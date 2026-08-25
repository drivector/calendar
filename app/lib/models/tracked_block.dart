import 'planned_block.dart';

/// Whether [tracked] corresponds to something that was planned — either
/// explicitly linked via [TrackedBlock.plannedBlockId] (set by the goal
/// list's "complete" button), or, for an entry logged by hand without
/// going through that flow, simply overlapping a planned block in the
/// same category. Logging an activity that happens to match a plan
/// should read as "this was planned" even if the user never tapped
/// Complete — see [ActualBlockWidget]'s own doc comment for how this
/// feeds the dashed-outline treatment.
bool trackedBlockWasPlanned(TrackedBlock tracked, List<PlannedBlock> planned) {
  if (tracked.plannedBlockId != null) return true;
  return planned.any(
    (p) =>
        p.categoryId == tracked.categoryId &&
        p.start.isBefore(tracked.end) &&
        tracked.start.isBefore(p.end),
  );
}

/// A block is [deleted] rather than physically removed from Firestore when
/// the user deletes it from the Activities list — the document itself
/// stays, so nothing is unrecoverable-by-design at the storage layer, even
/// though nothing in the app currently offers an undo. [active] is the
/// default for every block, including the many already-written documents
/// that predate this field entirely (see [TrackedBlock.fromMap]).
enum TrackedBlockStatus { active, deleted }

class TrackedBlock {
  const TrackedBlock({
    required this.id,
    required this.start,
    required this.end,
    required this.title,
    required this.categoryId,
    required this.sourceId,
    this.confidence = 1.0,
    this.plannedBlockId,
    this.note,
    this.status = TrackedBlockStatus.active,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final String title;
  final String categoryId;

  /// e.g. "health", "jira", "calendar", "manual".
  final String sourceId;
  final double confidence;

  /// The [PlannedBlock.id] this resolves against, if any.
  final String? plannedBlockId;

  /// Free-text detail from the Log activity sheet's Note field — null when
  /// left blank, never an empty string.
  final String? note;

  final TrackedBlockStatus status;

  Duration get duration => end.difference(start);

  /// A copy with [status] changed — used for the Activities list's soft
  /// delete, which is the only mutation this needs; every other field is
  /// reconstructed in full at its own call site (this app's established
  /// pattern — see `LogActivitySheet._save()`).
  TrackedBlock copyWithStatus(TrackedBlockStatus status) => TrackedBlock(
    id: id,
    start: start,
    end: end,
    title: title,
    categoryId: categoryId,
    sourceId: sourceId,
    confidence: confidence,
    plannedBlockId: plannedBlockId,
    note: note,
    status: status,
  );

  factory TrackedBlock.fromMap(String id, Map<String, dynamic> map) =>
      TrackedBlock(
        id: id,
        start: DateTime.parse(map['start'] as String),
        end: DateTime.parse(map['end'] as String),
        title: map['title'] as String,
        categoryId: map['categoryId'] as String,
        sourceId: map['sourceId'] as String,
        confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
        plannedBlockId: map['plannedBlockId'] as String?,
        note: map['note'] as String?,
        status: TrackedBlockStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => TrackedBlockStatus.active,
        ),
      );

  Map<String, dynamic> toMap() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'title': title,
    'categoryId': categoryId,
    'sourceId': sourceId,
    'confidence': confidence,
    'plannedBlockId': plannedBlockId,
    'note': note,
    'status': status.name,
  };
}
