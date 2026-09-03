import 'planned_block.dart';

/// The specific [PlannedBlock] a [start, end) span in [categoryId]
/// corresponds to, if any — either explicitly linked via [plannedBlockId]
/// (set by the goal list's "complete" button, for a [TrackedBlock]), or
/// whichever planned block it overlaps in the same category (the first
/// one found, if more than one). The primitive form behind both
/// [matchingPlannedBlockFor] (a completed [TrackedBlock]) and the
/// in-progress live activity's own matching in `TimeBodyGrid` — a running
/// activity has no [TrackedBlock] yet to call the other overload with.
PlannedBlock? matchingPlannedBlockForRange({
  required DateTime start,
  required DateTime end,
  required String categoryId,
  required List<PlannedBlock> planned,
  String? plannedBlockId,
}) {
  if (plannedBlockId != null) {
    for (final p in planned) {
      if (p.id == plannedBlockId) return p;
    }
  }
  for (final p in planned) {
    if (p.categoryId == categoryId &&
        p.start.isBefore(end) &&
        start.isBefore(p.end)) {
      return p;
    }
  }
  return null;
}

/// The specific [PlannedBlock] [tracked] corresponds to, if any — see
/// [matchingPlannedBlockForRange]. Used both for [trackedBlockWasPlanned]'s
/// dashed-outline signal and — since an actual block should visually sit
/// over *this specific* plan rather than just somewhere in the shared
/// time slot — for lining an actual block's own side-by-side column up
/// with its matching plan's column (see `TimeBodyGrid`'s own layout code).
PlannedBlock? matchingPlannedBlockFor(
  TrackedBlock tracked,
  List<PlannedBlock> planned,
) => matchingPlannedBlockForRange(
  start: tracked.start,
  end: tracked.end,
  categoryId: tracked.categoryId,
  planned: planned,
  plannedBlockId: tracked.plannedBlockId,
);

/// Whether [tracked] corresponds to something that was planned — either
/// explicitly linked via [TrackedBlock.plannedBlockId] (set by the goal
/// list's "complete" button), or, for an entry logged by hand without
/// going through that flow, simply overlapping a planned block in the
/// same category. Logging an activity that happens to match a plan
/// should read as "this was planned" even if the user never tapped
/// Complete — see [ActualBlockWidget]'s own doc comment for how this
/// feeds the dashed-outline treatment.
///
/// Deliberately *not* just `matchingPlannedBlockFor(...) != null`: an
/// explicit [TrackedBlock.plannedBlockId] link is trusted on its own,
/// even if the plan it names isn't in [planned] any more (e.g. deleted
/// since) — this still reads as "this was planned", it just has nothing
/// left to visually line up with. [matchingPlannedBlockFor] can only ever
/// point at a plan actually present in the list, which is exactly what a
/// caller that needs the real object (lining an actual block's column up
/// with its plan's) requires instead.
bool trackedBlockWasPlanned(TrackedBlock tracked, List<PlannedBlock> planned) {
  if (tracked.plannedBlockId != null) return true;
  return matchingPlannedBlockFor(tracked, planned) != null;
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
