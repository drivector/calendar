# Calendar Tracker — working conventions

For current project state (what's built, git/Firebase status, next steps),
read `HANDOFF.md` at this repo's root — that's the living status doc. This
file is durable conventions that don't change from session to session.

## Stack

Flutter app in `app/`, targeting macOS + iOS first (Android/Windows planned
later). State via `flutter_riverpod`, no codegen —
`StateNotifierProvider`s for mutable collections, derived `Provider`s for
computed values.

## Design system — Modernist

Flat, **zero border-radius** everywhere — no rounded corners, no shadows, no
gradients. Archivo for display/UI text, a monospace face (Menlo/SF Mono
fallback) for numeric/annotation text. Accent red `#ec3013`. Category colors
are pre-converted OKLCH hues — check `theme/app_category_colors.dart` before
inventing a new one. Buttons and small controls get a real border and a real
tap target (≥32×32, ideally 44×44 on primary actions) — never bare colored
text as a tap target.

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
