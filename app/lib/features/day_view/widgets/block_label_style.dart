/// How much text a plan/actual block on the Day view timeline has room to
/// show, decided by [TimeBodyGrid] from the block's own real, unclamped
/// height (see its own doc comment on why blocks are never resized to fit
/// text any more) — [ActualBlockWidget] and [PlanBlockWidget] both switch
/// on this rather than deciding for themselves.
enum BlockLabelStyle {
  /// Room for the normal two-line layout: a title, then a secondary line.
  full,

  /// Not enough room for two lines, but enough for one combined line
  /// ("15m · Walk").
  compact,

  /// Too short for even one line to render without clipping — the block
  /// shows as a plain colored bar, no text, rather than cramming in
  /// something illegible.
  hidden,
}
