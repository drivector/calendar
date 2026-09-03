/// How much text a plan/actual block on the Day view timeline has room to
/// show, decided by [TimeBodyGrid] from the block's own real, unclamped
/// height (see its own doc comment on why blocks are never resized to fit
/// text any more) — [ActualBlockWidget] and [PlanBlockWidget] both switch
/// on this rather than deciding for themselves.
///
/// No "hidden" tier any more — a block used to go label-less below a
/// height floor, but a genuinely short activity (under ~20 minutes) still
/// needs to be identifiable at a glance, so [compact] now always renders
/// even on a block shorter than one text line; its label simply overflows
/// past the block's own tiny box rather than disappearing.
enum BlockLabelStyle {
  /// Room for the normal two-line layout: a title, then a secondary line.
  full,

  /// Not enough room for two lines — a single combined line ("15m ·
  /// Walk"), shown regardless of how little vertical room the block
  /// itself actually has.
  compact,
}
