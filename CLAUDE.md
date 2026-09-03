# Calendar Tracker — working conventions

For current project state (what's built, git/Firebase status, next steps),
read `HANDOFF.md` at this repo's root — that's the living status doc. This
file is durable conventions that don't change from session to session.

## Stack

Flutter app in `app/`, targeting macOS + iOS first (Android/Windows planned
later). State via `flutter_riverpod`, no codegen —
`StateNotifierProvider`s for mutable collections, derived `Provider`s for
computed values.

## Design system — Outlook / Fluent 2

The app is styled to match the **Microsoft Outlook Calendar**. (It used to
use a flat, zero-radius "Modernist" system — that was deliberately replaced,
so don't reintroduce square corners or heavy black rules.)

- **Shape & elevation** live in `theme/app_shapes.dart`: `AppShapes.small`
  (4px — buttons, inputs, chips, event blocks), `.medium` (8px — cards,
  menus, dialogs), `.sheetTop` (12px top corners for bottom sheets), plus
  `shadow2` (resting cards) and `shadow8` (flyouts/menus/sheets). Reach for
  these rather than inventing a radius.
- **Colour** in `theme/app_colors.dart`: accent is Outlook blue `#0F6CBD`;
  `surface` (white) for cards/bars/sheets sitting on the `bg` canvas;
  `text` / `textSecondary` for primary vs annotation text; `divider` and
  the `neutral*` ramp for hairlines. Separators are **1px hairlines**, not
  2px rules.
- **Type**: the **platform system font** (SF Pro on iOS/macOS) — no
  `google_fonts`, no monospace. `AppTextStyles.mono()`/`monoLarge()` keep
  their names for continuity but now just mean *secondary annotation text*.
- **Category colours** are Outlook's own palette — check
  `theme/app_category_colors.dart` and `categoryColorPalette` in
  `state/categories_providers.dart` before inventing a new one. Note
  `meetings` is no longer pinned to the accent (it would collide with the
  blue).
- **Copy is sentence case** ("Save changes", "+ New goal"), not SHOUTY —
  except `AppTextStyles.kicker()` section headers, which stay uppercase.
- Exactly **one filled accent button per surface** (the primary action);
  everything else is neutral/bordered.
- Buttons and small controls still get a real border and a real tap target
  (≥32×32, ideally 44×44 on primary actions) — never bare colored text as a
  tap target. The widget tests assert this.

## Every code change

From `app/`:
```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter analyze
flutter test
```
Both clean before considering a change done. Add/update tests for new
behavior rather than only manually eyeballing it.

## Verification

Prefer checking real behavior — iOS Simulator or the macOS build — over
code review alone; several real bugs this project has had only surfaced by
actually running the app. If live verification isn't possible (this
environment has had persistent iOS Simulator tap-coordinate unreliability,
and no macOS screen-capture permission), fall back to precise widget-tree
assertions (rendered `Size`, `BoxDecoration`, exact text) rather than
claiming something was visually checked when it wasn't.

## Parallel sessions

When multiple agent sessions work on this repo at once, each one must work
in its own git worktree (`EnterWorktree`) on its own branch — never share a
single checkout, since `flutter analyze`/`test` and file edits from two
sessions in the same directory will collide.

- Scope each session to a specific area (a screen, a provider, a feature
  folder) to minimize overlap. The `StateNotifierProvider` files under
  `state/` are the most likely conflict point if two sessions touch the
  same one.
- Each session still follows every rule in this file (analyze/test clean,
  ask before commit/push, no new docs).
- Don't edit `HANDOFF.md` from more than one session concurrently — leave
  it to whichever session merges last, or to the user.
- A session should report its branch back rather than merging or pushing
  itself; branches get merged into `main` one at a time, re-running
  `flutter analyze && flutter test` after each merge before merging the
  next — two branches can conflict on merge even if their file scopes
  didn't overlap.
- Worktrees branch from `origin/main` by default, not the current
  session's in-progress branch — say so explicitly if a new session should
  instead build on another session's uncommitted/unmerged work.

## Riverpod gotcha

A `WidgetRef` passed into a widget from its caller (not the widget's own
`ref`) must use `.read()`, not `.watch()`, inside that widget's own
`build()` — watching from a borrowed ref risks a Riverpod assertion.

## Don't

- Don't create documentation files beyond `HANDOFF.md` (kept deliberately
  up to date) unless asked.
- Don't `git commit`/`git push` without asking first, each time — a prior
  approval doesn't carry forward to the next batch of changes.
- Don't add abstractions, config flags, or defensive handling for scenarios
  that can't happen in this app's current scope.
