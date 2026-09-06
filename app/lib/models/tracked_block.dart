import '../utils/day_range.dart';
import 'planned_block.dart';

/// The specific [PlannedBlock] a [start, end) span belonging to [goalId]
/// corresponds to, if any — either explicitly linked via [plannedBlockId]
/// (set by the goal list's "complete" button, for a [TrackedBlock]), or
/// whichever planned block it overlaps for the same goal (the first one
/// found, if more than one). The primitive form behind both
/// [matchingPlannedBlockFor] (a completed [TrackedBlock]) and the
/// in-progress live activity's own matching in `TimeBodyGrid` — a running
/// activity has no [TrackedBlock] yet to call the other overload with.
PlannedBlock? matchingPlannedBlockForRange({
  required DateTime start,
  required DateTime end,
  required String goalId,
  required List<PlannedBlock> planned,
  String? plannedBlockId,
}) {
  if (plannedBlockId != null) {
    for (final p in planned) {
      if (p.id == plannedBlockId) return p;
    }
  }
  for (final p in planned) {
    if (p.goalId == goalId && p.start.isBefore(end) && start.isBefore(p.end)) {
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
/// Returns null for an untimed [tracked] block (see [TrackedBlock]'s own
/// doc comment) — with no clock position there is nothing to overlap a
/// plan with, and an explicit [TrackedBlock.plannedBlockId] link is never
/// set on one. This used to answer from a fabricated span instead, so a
/// quick-logged "any time" entry silently bound itself to whichever plan
/// for the same goal happened to cover midday.
PlannedBlock? matchingPlannedBlockFor(
  TrackedBlock tracked,
  List<PlannedBlock> planned,
) {
  final start = tracked.start;
  final end = tracked.end;
  if (start == null || end == null) return null;
  return matchingPlannedBlockForRange(
    start: start,
    end: end,
    goalId: tracked.goalId,
    planned: planned,
    plannedBlockId: tracked.plannedBlockId,
  );
}

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

/// One logged activity. Two shapes, distinguished by whether [start] is
/// null:
///
/// * **Timed** (the default constructor) — a real clock span the user did
///   something in, e.g. 09:00–10:30. Drawn on the Day view's timeline,
///   sorted chronologically, matched against plans by overlap.
/// * **Untimed** ([TrackedBlock.untimed]) — an amount of time credited to
///   a [day] with no clock position at all, e.g. "piano, 15 min, any
///   time". The shape a goal's plain-duration schedule entry produces (see
///   `logUnscheduledGoalTime`), mirroring [DayScheduleEntry]'s own
///   duration-vs-time-range split on the planning side.
///
/// [day] and [duration] are always real and always meaningful, whichever
/// shape this is — every day-membership and totalling calculation goes
/// through them and needs no null handling. [start]/[end] are nullable
/// precisely so that an untimed block *cannot* be read as having happened
/// at a clock time it never had: this class used to store a fabricated
/// span alongside a `hasNoTime` flag, and the fabricated values leaked
/// into list ordering, plan matching and day attribution wherever a
/// caller forgot to check the flag.
class TrackedBlock {
  /// A timed block, from the real span it occupied. [day] is derived from
  /// [start] (an overnight block belongs to the day it started on, the
  /// same convention [groupTrackedBlocksByDay] uses), so the two can never
  /// disagree.
  TrackedBlock({
    required this.id,
    required DateTime start,
    required DateTime end,
    required this.title,
    required this.goalId,
    required this.sourceId,
    this.confidence = 1.0,
    this.plannedBlockId,
    this.note,
    this.status = TrackedBlockStatus.active,
  }) : day = dateOnly(start),
       start = start,
       duration = end.difference(start);

  /// An untimed block — [duration] credited to [day], with no clock
  /// position. Written only by `logUnscheduledGoalTime`, for a goal whose
  /// schedule entry never had a slot to begin with.
  TrackedBlock.untimed({
    required this.id,
    required DateTime day,
    required this.duration,
    required this.title,
    required this.goalId,
    required this.sourceId,
    this.confidence = 1.0,
    this.plannedBlockId,
    this.note,
    this.status = TrackedBlockStatus.active,
  }) : day = dateOnly(day),
       start = null;

  TrackedBlock._({
    required this.id,
    required this.day,
    required this.start,
    required this.duration,
    required this.title,
    required this.goalId,
    required this.sourceId,
    required this.confidence,
    required this.plannedBlockId,
    required this.note,
    required this.status,
  });

  final String id;

  /// The calendar day (time-of-day zeroed) this block is credited to —
  /// always meaningful, for both shapes. What every "does this belong to
  /// this day" filter keys off.
  final DateTime day;

  /// How long the activity took — always meaningful, for both shapes.
  final Duration duration;

  /// When it started, or null if it has no clock position at all (see the
  /// class doc comment). Never a placeholder: null genuinely means "the
  /// user never said when".
  final DateTime? start;

  /// Derived from [start] + [duration], and null for exactly the same
  /// reason [start] is. Rolls past midnight for an overnight block.
  DateTime? get end => start?.add(duration);

  /// Whether this block has a real clock position — the one check every
  /// display site that wants to draw or print a time needs to make before
  /// dereferencing [start]/[end].
  bool get isTimed => start != null;

  final String title;

  /// Every tracked activity belongs to a goal — its category is looked up
  /// via `goalById` in `state/goals_providers.dart`, never stored on this
  /// class directly. See [PlannedBlock.goalId]'s doc comment for the same
  /// reasoning applied here.
  final String goalId;

  /// e.g. "health", "jira", "calendar", "manual".
  final String sourceId;
  final double confidence;

  /// The [PlannedBlock.id] this resolves against, if any.
  final String? plannedBlockId;

  /// Free-text detail from the Log activity sheet's Note field — null when
  /// left blank, never an empty string.
  final String? note;

  final TrackedBlockStatus status;

  /// Whether this block belongs on [date]'s own column. A timed block uses
  /// [overlapsDay], so an overnight one shows on both days it touches; an
  /// untimed one has only its [day] to go on.
  bool occursOn(DateTime date) {
    final start = this.start;
    if (start == null) return isSameDay(day, date);
    return overlapsDay(start, start.add(duration), date);
  }

  /// How much of [duration] actually falls on [date] — the real overlap
  /// with [date]'s own [00:00, 24:00) span, not the whole [duration]. For
  /// an overnight block this is less than [duration] on both of the days
  /// [occursOn] returns true for (e.g. 2h before midnight, 6h after);
  /// callers that already sum per-day get the block's real total exactly
  /// once by adding both, rather than double-counting a full [duration]
  /// on each day it touches. An untimed block has no clock position to
  /// clip against, so its whole [duration] belongs to [day].
  Duration durationOn(DateTime date) {
    final start = this.start;
    if (start == null) return duration;
    final end = start.add(duration);
    final (dayStart, dayEnd) = dayBounds(date);
    final clampedStart = start.isBefore(dayStart) ? dayStart : start;
    final clampedEnd = end.isAfter(dayEnd) ? dayEnd : end;
    final overlap = clampedEnd.difference(clampedStart);
    return overlap.isNegative ? Duration.zero : overlap;
  }

  /// A copy with [status] changed — used for the Activities list's soft
  /// delete, which is the only mutation this needs; every other field is
  /// reconstructed in full at its own call site (this app's established
  /// pattern — see `LogActivitySheet._save()`).
  TrackedBlock copyWithStatus(TrackedBlockStatus status) => TrackedBlock._(
    id: id,
    day: day,
    start: start,
    duration: duration,
    title: title,
    goalId: goalId,
    sourceId: sourceId,
    confidence: confidence,
    plannedBlockId: plannedBlockId,
    note: note,
    status: status,
  );

  /// Reads both the current shape (`day` + `durationSeconds`, with `start`
  /// present only for a timed block) and the original one (`start` + `end`
  /// + a `hasNoTime` flag), so already-written documents keep loading
  /// without a backfill. A legacy untimed document's day is taken from its
  /// `end` — `logUnscheduledGoalTime` used to anchor those at noon and
  /// count backwards, so `start` could land on the *previous* day for
  /// anything over 12 hours, while `end` was always on the right one.
  factory TrackedBlock.fromMap(String id, Map<String, dynamic> map) {
    final title = map['title'] as String;
    final goalId = map['goalId'] as String;
    final sourceId = map['sourceId'] as String;
    final confidence = (map['confidence'] as num?)?.toDouble() ?? 1.0;
    final plannedBlockId = map['plannedBlockId'] as String?;
    final note = map['note'] as String?;
    final status = TrackedBlockStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => TrackedBlockStatus.active,
    );
    final startRaw = map['start'] as String?;
    final durationSeconds = map['durationSeconds'] as int?;

    if (durationSeconds != null) {
      final duration = Duration(seconds: durationSeconds);
      if (startRaw != null) {
        return TrackedBlock(
          id: id,
          start: DateTime.parse(startRaw),
          end: DateTime.parse(startRaw).add(duration),
          title: title,
          goalId: goalId,
          sourceId: sourceId,
          confidence: confidence,
          plannedBlockId: plannedBlockId,
          note: note,
          status: status,
        );
      }
      return TrackedBlock.untimed(
        id: id,
        day: DateTime.parse(map['day'] as String),
        duration: duration,
        title: title,
        goalId: goalId,
        sourceId: sourceId,
        confidence: confidence,
        plannedBlockId: plannedBlockId,
        note: note,
        status: status,
      );
    }

    final start = DateTime.parse(startRaw!);
    final end = DateTime.parse(map['end'] as String);
    if (map['hasNoTime'] as bool? ?? false) {
      return TrackedBlock.untimed(
        id: id,
        day: end,
        duration: end.difference(start),
        title: title,
        goalId: goalId,
        sourceId: sourceId,
        confidence: confidence,
        plannedBlockId: plannedBlockId,
        note: note,
        status: status,
      );
    }
    return TrackedBlock(
      id: id,
      start: start,
      end: end,
      title: title,
      goalId: goalId,
      sourceId: sourceId,
      confidence: confidence,
      plannedBlockId: plannedBlockId,
      note: note,
      status: status,
    );
  }

  /// `start` is written as null rather than a placeholder for an untimed
  /// block — that null is the stored form of "this never had a clock
  /// time", and `firestore.rules` allows it explicitly.
  Map<String, dynamic> toMap() => {
    'day': day.toIso8601String(),
    'start': start?.toIso8601String(),
    'durationSeconds': duration.inSeconds,
    'title': title,
    'goalId': goalId,
    'sourceId': sourceId,
    'confidence': confidence,
    'plannedBlockId': plannedBlockId,
    'note': note,
    'status': status.name,
  };
}
