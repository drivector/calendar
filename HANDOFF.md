# Calendar Tracker — session handoff

Updated 2026-08-24 (fifth session, now committed as `5e69f6c` — not yet
pushed, see **Git status**) — Firebase Auth + Firestore are built and
live; the fourth session added five goal/logging UX fixes, CI, and iPhone
install readiness. The fifth session was large — in rough order: fixed a
real gap in the fourth session's own unsaved-changes work (barrier-tap
did nothing instead of prompting), added a **Capacity** page off the Week
view, fixed two real gaps in the goal detail sheet (hidden date range,
today-only target), added **week-to-week navigation** to that same sheet,
added a **"complete" button** to the Goals list (turns a goal's remaining
planned blocks into tracked activity in one tap), renamed the **"+ Log"
tab to Activities** (a day-by-day history list instead of a single-day
form, with logging moved to a "+ LOG" action that lets you pick the day
and validates missing fields instead of silently failing), built
**onboarding** for brand-new accounts (9 predefined categories, prompted
to create a first goal before reaching the app), gave the **Day view's
add-block sheet** a goal picker and independent start/end dates, and
**removed the cap goal type entirely** (every goal is a target now).
Each has its own dated section below with full detail — read this intro
for the shape of things, then jump to whichever section is relevant.
Read this first, then verify anything time-sensitive (git
status, test count, Firebase console state) since it may have moved on
since this was written.

## What this project is

A Flutter time-tracking calendar app ("Calendar Tracker" / Firebase project name
"TrackMyDay"), built from a design handoff at
`design_handoff_time_tracking_calendar/README.md`. Targets macOS + iOS first,
Android + Windows planned later. Modernist design system: flat, 0 border-radius,
Archivo font (mono via IBM Plex Mono equivalent — actually Menlo/SF Mono
fallback), red accent `#ec3013`, OKLCH-derived category hues.

Repo root: `/Users/alexandrospanagiotidis/DriVector/Calendar/`
Flutter app: `/Users/alexandrospanagiotidis/DriVector/Calendar/app/`
Git remote: `https://github.com/drivector/calendar.git` — up to date, see
**Git status** below.

## Stack

- Flutter, `flutter_riverpod` for state (derived `Provider`s for computed
  values, `StreamProvider`s over Firestore for live collections — no
  codegen).
- **Firebase Auth (email/password) + Firestore** are wired in — see
  **Authentication + Firestore backend** below. A signed-in account's
  goals/categories/planned/tracked blocks live in Firestore under
  `users/{uid}/...` and start **empty** for a new account; the old
  in-memory mock/dummy data (`lib/data/mock/`) is now only a **test
  fixture**, seeded into a fake Firestore in tests — it no longer feeds the
  real app.
- Local Flutter SDK at `~/development/flutter/bin` (already on PATH via
  `~/.zshrc`).

## What's built so far

Four tabs (Day / Week / Goals / +Log) hosted in `RootShell` behind an
`IndexedStack`, plus a Categories admin screen (pushed as a route, not a tab)
and a Claim-untracked-time bottom sheet.

- **Day view** — continuous 24h timeline, Plan lane + Actual lane, tap empty
  space to create a planned/actual entry, tap a block/gap for its detail.
  Header has `<`/`>` arrow buttons plus touch-swipe and trackpad-swipe for
  day navigation (`DateSwipeNav`).
- **Week view** — 7 day rows with live per-day category bars, **derived from
  real block data** (not synthetic — this was a mid-session refactor), same
  `<`/`>` + swipe navigation pattern for week-to-week.
- **Goals** — each goal has a **unified per-day schedule**: every weekday
  holds a list of `DayScheduleEntry`, each either a plain duration or a clock
  time range (a day can mix several of either — e.g. a split shift, or a time
  range plus extra untimed duration). The day's target is the sum. Every goal
  always has a start/end date (no separate "ongoing" flag — an ongoing habit
  is just a date range ~1 year out). A goal's own schedule is **rendered live
  into the Day view as real planned blocks** (`generateGoalPlannedBlocksForDate`
  in `lib/models/goal_planned_blocks.dart`) — duration-only entries are placed
  greedily avoiding overlaps and marked `isGoalAutoPlaced` (shown as
  "auto-placed" in the UI, distinct from a real fixed time-range commitment).
  Only `GoalType.target` goals generate blocks — `cap` goals (a ceiling, not
  a plan) never do.
- **Activities** (was "+ Log") — every tracked activity ever, grouped
  into a day-by-day list (most recent day first); the manual-entry form
  is now a "+ LOG" action on this page (a sheet, with its own Day field —
  logging for a day other than today doesn't require leaving the sheet),
  not the tab itself — see **"+ Log" tab renamed to Activities**, **Log
  activity sheet: pick the day first**, and **Activities screen:
  day-by-day list** below.
- **Categories admin** — full CRUD, color palette picker.
- **Navigation** — Day/Week own horizontal swipe+trackpad for date/week
  stepping. Goals and +Log (which have no competing horizontal gesture) use
  the same `DateSwipeNav` widget for **tab-switching** instead (swipe
  left/right moves between tabs, clamped at the ends). Day/Week were
  deliberately left out of tab-switch swipe to avoid two nested gesture
  handlers fighting over one swipe.

### Key files
- `lib/models/goal.dart` — `Goal`, `DayScheduleEntry`, `GoalType`.
- `lib/models/goal_planned_blocks.dart` — pure function generating Day-view
  blocks from goals' schedules; overlap-avoidance logic lives here.
- `lib/models/goal_progress.dart` — pace/status computation, `weekStartFor`.
- `lib/state/goals_providers.dart` — `goalsProvider`,
  `goalGeneratedBlocksThisWeekProvider`, `dayViewPlannedBlocksProvider`
  (merges manual + goal-generated blocks for the Day view).
- `lib/state/week_view_providers.dart` — live (not synthetic)
  `weekDaySummariesProvider`.
- `lib/features/goals/widgets/goal_edit_sheet.dart` — the unified schedule
  editor UI (`_DayScheduleSection`, `_EntryDurationRow`, `_EntryTimeRangeRow`).
- `lib/shared/widgets/date_swipe_nav.dart` — the reusable swipe/trackpad
  widget, now used for both date-nav and tab-switching (never both on one
  screen — see its doc comment for why).
- `lib/data/mock/mock_goals.dart`, `mock_day_20aug.dart`, `dummy_data.dart` —
  now **test-fixture-only** seed data (see **Authentication + Firestore
  backend**), no longer wired into the live app. `dummy_data.dart` is still
  user-editable if you want to change what the test fixture seeds.

## Testing

`flutter analyze` is clean; `flutter test` currently passes **123 tests**
across `test/models/`, `test/state/`, `test/utils/`, `test/widget_test.dart`,
and `test/features/auth/login_screen_test.dart`. Convention: after any
change, run both and fix before moving on. Run from `app/`:
```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter analyze
flutter test
```
Screen/provider tests that reach `RootShell` now need a signed-in fixture,
since `RootShell` sits behind the Firebase auth gate and its providers are
Firestore-backed. `test/support/firestore_test_fixtures.dart` has
`seededFirestore(uid)`, which pre-populates a `FakeFirebaseFirestore`
(package `fake_cloud_firestore`) with the mock/dummy data under
`users/{uid}/...`; pair it with `firebase_auth_mocks`'
`MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid))` overriding
`firebaseAuthProvider`, and override `firestoreProvider` with that fake
Firestore. See `_signedInOverrides()` in `widget_test.dart` for the pattern.
One gotcha hit repeatedly: `MockFirebaseAuth`'s first `authStateChanges()`
emission is asynchronous, and every per-user repository provider depends on
it via `currentUidProvider` — so in a plain (non-widget) test, `await
container.read(authStateChangesProvider.future)` before touching anything
uid-dependent, or the `requireValue` call in `currentUidProvider` throws on
`AsyncLoading`. Widget tests don't need this explicitly since
`pumpAndSettle()` flushes it.

## Git status — fifth session is committed, not yet pushed

- The Firebase Auth/Firestore backend and the fourth session's UX
  fixes/CI are committed and pushed to `drivector/calendar` main
  (`55e84e7`, `0c6414a`, `78a0beb`, `52d922a`). The entire **fifth
  session** — everything from the duration-format spacing fix through the
  cap-removal and Day view goal-picker work described below — is now one
  commit, **`5e69f6c`**, on top of those. **Not yet pushed** — ask before
  pushing, per this repo's `CLAUDE.md` (a prior commit approval doesn't
  carry forward to push, and vice versa; each needs its own go-ahead).
- Commit author identity on this repo was auto-detected from the local
  username/hostname (`Alexandros Panagiotidis
  <alexandrospanagiotidis@192.168.1.5>`) rather than a real email — flagged
  to the user once already, not fixed (never touch git config unasked).
  Still worth checking `git config --global user.email` before the next
  commit if GitHub attribution matters.
- Pushing needs **GitHub CLI** (`gh`), installed via Homebrew at
  `/opt/homebrew/bin/gh` and authenticated as the `drivector` account
  (`repo` scope). **`/opt/homebrew/bin` may not be on PATH in a fresh
  non-interactive shell** — add it explicitly
  (`export PATH="/opt/homebrew/bin:$PATH"`) before relying on `gh`, `brew`,
  `firebase`, or `flutterfire` (the latter two also need
  `$HOME/.npm-global/bin` and `$HOME/.pub-cache/bin` respectively, plus the
  Flutter SDK's `bin` on PATH since `flutterfire` shells out to `dart`).

## Goal detail sheet: week navigation (fifth session)

The user asked to be able to browse a goal's target-vs-actual and activity
lists week by week, not just see the current one. `goal_detail_sheet.dart`
was entirely rewritten from `ConsumerWidget` to `ConsumerStatefulWidget`:

- `GoalDetailSheet` now holds its own local `_weekStart` state (`initState`
  seeds it from the app's *current* selected week via
  `weekStartFor(widget.ref.read(selectedDateProvider))`, then a
  `StepArrowButton` pair — the same widget the Day/Week headers use — steps
  it ±7 days via `setState`). This is deliberately **independent of
  `selectedDateProvider`**: browsing weeks inside the sheet must not shift
  the Day/Week/Goals screens behind it. Covered by a test that steps
  forward, back, closes the sheet, and confirms the Day view still shows
  the original mock day untouched.
- Everything the sheet shows is now computed **locally for `_weekStart`**
  instead of read from providers pinned to the globally-selected week:
  - The goal itself comes from `goalsProvider` (a live list), found by id,
    rather than `goalProgressListProvider` (which only ever computed
    progress for the current week).
  - Goal-generated planned blocks come from calling
    `generateGoalPlannedBlocksForDate` directly in a 7-day loop over
    `_weekStart`, instead of `goalGeneratedBlocksThisWeekProvider` (also
    pinned globally).
  - `plannedActivity`/`actualActivity` filter manual + generated blocks by
    category and the local week bounds, same as before but against
    `_weekStart`/`weekEnd` instead of the global week.
  - `GoalProgress` (the bar + status text) is now built by calling
    `computeGoalProgress` directly with locally-summed
    planned/actual hours, rather than reusing a precomputed value from the
    list provider. Its `date` param (used for "expected by now" pacing)
    goes through a new `_clampToWeek` helper: the real "today" when
    browsing the current week, clamped to the week's start/end otherwise —
    so a fully past week reads as 100% expected and a future week as 0%,
    rather than pace math running against a today that isn't even in the
    browsed week.
- Added a week-range header ("17 Aug – 23 Aug" style, `DateFormat('d
  MMM')`) with the `StepArrowButton` prev/next pair next to it, near the
  top of the sheet.
- Dropped the "· today X" fragment from the **target** stat row (it's
  ambiguous once browsing a non-current week, and already redundant with
  the per-day strip) — the row is now just the plain weekly target
  duration.
- "PLANNED THIS WEEK"/"ACTUAL THIS WEEK" kickers shortened to
  "PLANNED"/"ACTUAL" (the week range is now shown explicitly by the new
  header, so repeating "this week" in both section titles was redundant);
  the empty-state copy under each ("Nothing planned yet." / "No activity
  yet.") was likewise reworded to "...this week." to stay accurate once
  browsing).
- `_dayLabel` (used in each planned/actual row) changed from `EEE` to `EEE
  d` (e.g. "MON 17") — a bare weekday name is ambiguous once the sheet can
  show any week, not just the current one.

One new widget test (`test/widget_test.dart`) exercises the actual
navigation behavior end to end: opens Walking's detail (current week has
seeded activity every day), steps to the next week (nothing seeded there —
confirms both empty-state messages appear and "Walk 48 m" is gone), steps
back (confirms the original week's activity is back), then closes the
sheet and confirms the app's global selected date was never touched.
Existing tests needed two wording updates ("PLANNED THIS WEEK" →
"PLANNED", and the target row's now-shorter text) — verified: `flutter
analyze` clean, all 93 tests pass. Live tap-through wasn't attempted this
round either (see **Known environment quirks**) — same fallback as the
rest of this session, relying on the widget test's precise finders,
including one that actually taps the new step-arrow buttons and asserts
on the resulting content.

**Stale-build gotcha hit right after this shipped**: the user saw a red
error screen on the simulator — `type 'GoalDetailSheet' is not a subtype
of type 'ConsumerWidget?'`. Not a real bug: converting `GoalDetailSheet`
from `ConsumerWidget` to `ConsumerStatefulWidget` changes the widget's
runtime type shape, which Flutter can't hot-reload cleanly (the element
tree still expects the old type) — the simulator was just running a build
from before that edit. Fixed by a full `flutter build ios --debug
--simulator` + reinstall, not a code change. Worth remembering for any
future session/agent: after changing a widget between Stateless/Stateful
(or Consumer/ConsumerStateful), always do a fresh build + relaunch, not
rely on hot reload, before telling the user to look at the simulator.

**Follow-up polish round, same feature**: two more asks after the above
shipped —
1. Reordered the sheet again: the **active**/**runs** date row now comes
   *before* the week-range/nav row (was progress → status → active row;
   now active row → week row → progress → status), so the sheet reads
   "what this goal covers" before "which week you're looking at."
2. **Redesigned `StepArrowButton`** (`lib/shared/widgets/
   step_arrow_button.dart`) — the user didn't like the plain bordered-box
   `<`/`>` look. Presented 4 flat, zero-radius alternatives (bigger
   true-chevron target, a single joined two-arrow stepper, an
   accent-colored chevron, plus keeping the original) as an inline visual
   mockup; the user picked the accent-chevron option. Now: 36×36 (was
   32×32), 1.5px border (was 2px), a real `‹`/`›` chevron glyph (was
   ASCII `<`/`>`) colored the app's accent red `#ec3013` against the
   neutral border — the first UI element in the app to put color on a
   button glyph rather than a flat block/category swatch. This widget is
   shared by Day view, Week view, *and* the goal detail sheet's new
   week-nav (all three previously used identical plain arrows) — the
   redesign applies everywhere at once by construction, not a one-off for
   the goal sheet. No test asserted the button's exact size/glyph
   (confirmed by grep before changing it), so nothing needed updating;
   verified `flutter analyze` clean and all 93 tests still pass, plus a
   fresh simulator build showing the new accent chevrons live on the Day
   view header.

**Two more quick follow-ups on the same feature:**
1. **Swipe/trackpad gesture, not just the buttons.** The user asked to be
   able to move between weeks in the goal detail sheet "with the fingers"
   even without tapping the arrows. Wrapped the sheet's scrollable body in
   the existing `DateSwipeNav` (already used by Day/Week/Goals/Log for
   exactly this — touch drag + trackpad horizontal scroll, see its own doc
   comment), same pattern Week view uses: wraps the whole body, coexists
   fine with the sheet's vertical `SingleChildScrollView` since
   `DateSwipeNav` only claims the horizontal-drag gesture. One new widget
   test (`test/widget_test.dart`) uses `tester.fling` on the sheet the same
   way the existing Day-view swipe test does, confirming a fling steps the
   week exactly like tapping the next-arrow does, and a fling back returns
   to the original week.
2. **Shrunk `StepArrowButton`** back down from the 36×36 chosen in the
   design-options round to 32×32 (still meets CLAUDE.md's ≥32×32 floor for
   a real tap target — didn't go smaller than that), border down to
   matching 1.5px unchanged, glyph font-size 16→14 to stay proportional.
   Same shared widget, so this also shrank the Day/Week header arrows, not
   just the goal sheet's. No test asserted the exact size (confirmed by
   grep, same check as the redesign round), so nothing else needed
   updating. Verified: `flutter analyze` clean, all 94 tests pass (93 +
   the new swipe test), fresh simulator build confirms the smaller accent
   arrows on the Day view header.

## Goal list: "complete" button (fifth session)

New ask: a button next to each goal in the list that "automatically
reaches target and creates activities as per the planned" — i.e. turn a
followed plan into logged activity in one tap, rather than re-entering
each block by hand.

- **`lib/models/goal_completion.dart`** (new, pure, unit-tested in
  `test/models/goal_completion_test.dart`) —
  `pendingPlannedBlocksForGoal(goal, allPlanned, generatedThisWeek,
  allTracked, weekStart)` returns this goal's planned blocks for that week
  (manual, in its category, plus its own generated schedule — the same
  union `_plannedHoursForGoal` in `goals_providers.dart` already sums)
  that don't yet have a tracked block resolving them (matched by
  `TrackedBlock.plannedBlockId`). **Never returns anything for a
  `GoalType.cap` goal** — a cap is a ceiling to stay under, so
  "auto-complete it" would mean deliberately maxing it out, the opposite
  of the point; only `target` goals get the button at all.
  `trackedBlocksCompletingPlan(pending)` builds the actual `TrackedBlock`s
  — exact copies of each planned block's time/title/category,
  `sourceId: 'manual'`. The new tracked block's id is derived from the
  planned block's own id (`'complete-${block.id}'`), not a timestamp, so
  tapping the button twice before a write round-trips is idempotent
  (re-writes the same doc) rather than creating duplicates.
- **`CompleteGoalButton`** (`goal_block.dart`) — same bordered/
  accent-glyph visual family as `StepArrowButton` (32×32, 1.5px border,
  accent-red glyph — a checkmark instead of a chevron), so it reads as
  part of the same control language rather than a one-off.
- **`goals_screen.dart`** — each goal row is now a `Row`: the existing
  tappable `GoalBlock` (opens detail) in an `Expanded`, plus
  `CompleteGoalButton` as a sibling — **shown only when
  `pendingPlannedBlocksForGoal` is non-empty** for that goal, so a goal
  that's fully on-plan (or has nothing planned, or is cap-type) never
  shows a dead button. Tapping it fires one `upsert` per pending block
  through the existing `trackedBlocksRepositoryProvider` (fire-and-forget,
  matching every other write call site in the app).
- One new widget test seeds a Firestore fixture with one extra
  Walking-category planned block that has no matching tracked block
  (the standard shared fixture has every planned block already covered,
  by design, so nothing would ever show without this), confirms exactly
  one goal (Walking — Deep work's blocks are all covered, the rest are
  cap-type) shows the button, taps it, confirms the button disappears
  everywhere, then opens Walking's detail sheet and confirms the block now
  appears twice — once under PLANNED (unchanged) and once under ACTUAL
  (the new tracked block). Verified: `flutter analyze` clean, all 104
  tests pass (94 + 9 new unit tests + 1 new widget test). Live tap-through
  on the simulator wasn't achieved this round either (same documented
  flakiness, see **Known environment quirks**) — no crash on a fresh
  build/launch, but relying on the widget test for the actual behavior
  verification.

## "+ Log" tab renamed to Activities, logging moved to a page action (fifth session)

The 4th tab used to *be* the manual-entry form — tapping "+ LOG" dropped
you straight into an empty form, with no way to see what you'd already
logged without leaving the tab. Restructured per the user's request:

- **`lib/features/log_activity/activities_screen.dart`** (new,
  replaces the old `log_activity_screen.dart`) — `ActivitiesScreen`, the
  tab's new content: every `TrackedBlock` on the selected day (via the
  existing `trackedBlocksProvider`, already day-scoped — no new provider
  needed), sorted by start time, each row showing title, time range,
  source, and duration with a category-colored left bar (same visual
  language as the goal detail sheet's `_ActualRow`). Empty state: "No
  activity today." A **"+ LOG"** bordered button in the header (real
  border + ≥32×32 tap target, not bare text, per this repo's button
  convention) opens the entry form as a sheet.
- **`lib/features/log_activity/widgets/log_activity_sheet.dart`** (new)
  — the old full-screen form, unchanged in substance (same fields: goal
  chips, start/end pickers, note, weekly-target readout), now
  `showLogActivitySheet(context, ref)` opening it as a modal bottom sheet.
  Follows the same `ConsumerStatefulWidget`-with-a-borrowed-`ref` pattern
  as `GoalDetailSheet` — the sheet's own `ref` (from `ConsumerState`)
  handles `.watch()` for live field updates, `widget.ref` (the caller's,
  read-only per this repo's Riverpod gotcha) handles the one-off save.
  "cancel" → **"close"**, and now actually pops the sheet (it used to just
  clear the form and stay on-screen, since the form *was* the whole tab).
  Saving now closes the sheet and stays on Activities — the new entry
  shows up immediately, rather than jumping to the Day tab (the old
  behavior, no longer sensible once Log isn't a tab in its own right).
  Dropped the "or hold the + tab to start a live timer" hint line — it
  referred to a "+ tab" that no longer exists (no such hold gesture was
  ever built either; the line was stale even before this rename, just
  never noticed).
- **`root_shell.dart`** — tab label `'+ Log'` → `'Activities'`,
  `LogActivityScreen()` → `ActivitiesScreen()`.
- Test fallout: every existing test that tapped `'+ LOG'` expecting the
  form to appear directly now taps `'ACTIVITIES'` (the tab) then `'+
  LOG'` (the new in-page button) — the tab-switch/swipe tests only needed
  the label and `find.byType` rename, not the extra tap, since they never
  interacted with form fields. Two new tests cover the list itself
  directly (renders every tracked block for the day in start-time order;
  shows "No activity today." on an empty account) — neither existed for
  the old form-only tab, since there was nothing to list before. Verified:
  `flutter analyze` clean, all 106 tests pass (104 + 2 new). Confirmed
  live on the simulator that the tab bar itself now reads "ACTIVITIES"
  (no crash on a fresh build); tapping through to verify the list/sheet
  content live wasn't achieved this round (see **Known environment
  quirks**) — relying on the widget tests for that, which exercise the
  full list-render, open-sheet, save, and empty-state paths.

## Log activity sheet: pick the day first (fifth session)

Follow-up on the Activities rename above: the log form always logged
against whatever day the app happened to be showing (`selectedDateProvider`),
with no way to log for a different day without first leaving the sheet to
change the app's own date. Added a **Day** field, first in the form (above
Activity/Start/End), so choosing which day this entry belongs to is the
first thing the sheet asks — not an invisible assumption.

- **`DraftLogEntry`** (`log_entry_providers.dart`) gained a `date` field
  (`DateTime?`) + `setDate`, following the same shape as `start`/`end`.
- **`LogActivitySheet`** now seeds `draft.date` from the app's current
  `selectedDateProvider` in `initState` — but only if the draft doesn't
  already have one (it never does on a fresh open, since both `_close` and
  `_save` reset the draft) — so the common case ("log something for
  today") still needs no extra taps, it's just now an explicit, visible,
  editable default rather than a hidden one. **Gotcha hit**: Riverpod
  forbids modifying a provider from `initState` itself (`Tried to modify a
  provider while the widget tree was building`) — fixed by deferring the
  default-setting through `WidgetsBinding.instance.addPostFrameCallback`,
  guarded with `if (!mounted) return`.
- New `_DateField` widget (mirrors the existing `_TimeField`) opens Flutter's
  stock `showDatePicker` — same as `showTimePicker` already used
  unmodified elsewhere in this sheet and in `add_block_sheet.dart`, so
  reusing the stock (Material-rounded) picker here is consistent with
  existing precedent, not a new departure from the flat design system.
  Bounded `2020-01-01` – today (can't log a future activity).
- `_save()` now reads the day from `draft.date` instead of
  `ref.read(selectedDateProvider)`, and requires it non-null alongside
  start/end/goal before writing anything.
- Three tests: the existing "filling the form" test gained an assertion
  that the Day field shows the app's current day by default
  ("Thu, 20 Aug 2026"); a new test picks a different day (via the draft
  notifier directly, same pattern the existing save test already used for
  start/end/goal — driving Flutter's stock date-picker dialog through
  widget-test taps would be far more brittle than exercising the same
  state path), saves, and confirms the resulting `TrackedBlock` lands on
  the picked day, **not** the app's selected day — and that the app's
  `selectedDateProvider` itself was never touched, and that the Activities
  list (still showing the original day) doesn't show the entry that was
  actually logged for a different one. Verified: `flutter analyze` clean,
  all 107 tests pass (106 + 1 new — the other assertion was added to an
  existing test). Confirmed the app still launches cleanly on the
  simulator after the change; deeper interactive confirmation wasn't
  possible this round (see **Known environment quirks**), so relying on
  the widget tests as usual.

## Activities screen: day-by-day list instead of one day at a time (fifth session)

Follow-up on the two changes above: the Activities screen still only ever
showed one day's activity (whatever `selectedDateProvider` pointed at,
shared with Day/Week). Changed it to a running history instead — every
tracked activity, ever, grouped into day sections (most recent day first),
so the "Day" field just added to the log sheet is actually useful for
reviewing what you logged, not just narrowly matching what one screen
happens to be scrolled to.

- **`lib/models/activity_log.dart`** (new, pure, unit-tested in
  `test/models/activity_log_test.dart`) — `groupTrackedBlocksByDay(blocks)`
  returns `List<DayActivityGroup>` (`{day, blocks}`), grouped by calendar
  day, days most-recent-first, each day's own blocks in start-time order.
- **`ActivitiesScreen`** now watches `allTrackedBlocksProvider` (unscoped —
  the same provider the goal detail sheet and Capacity page already read
  from for their own week-wide sums) instead of the day-scoped
  `trackedBlocksProvider`, and renders `groupTrackedBlocksByDay`'s output
  directly: a `_DaySectionHeader` ("THURSDAY, 20 AUG" style — divider +
  kicker, same visual language as the goal detail sheet's "PLANNED"/
  "ACTUAL" section headers) above each day's `_ActivityRow`s. Dropped the
  single date subtitle from the header (no longer meaningful once the list
  spans every day) — just "Activities" + the "+ LOG" button now. Empty
  state reworded "No activity today." → "No activity yet." (accurate for
  an empty account regardless of day).
- Rewrote the two existing Activities-list tests for the new shape (one
  now confirms two different days both get their own section, in the
  right order, with each day's own blocks correctly grouped under it) and
  fixed the day-picker test from the previous round — its old assertion
  ("Yesterday's walk" should NOT appear, since the list used to be scoped
  to the app's selected day) is now backwards: the entry **does** show up,
  just filed under its own day's section rather than the currently
  browsed one, which is exactly the point of both this change and the
  Day-field one it follows on from. Verified: `flutter analyze` clean, all
  111 tests pass (107 + 4 new `groupTrackedBlocksByDay` unit tests).
  Confirmed the app still launches cleanly on the simulator; live
  tap-through wasn't achieved this round either (see **Known environment
  quirks**) — relying on the widget tests as usual.

## Bug found and fixed: logging an entry could silently do nothing (fifth session)

The user logged an activity for Sunday 23 Aug and it never showed up in
Activities. Root cause, found by re-reading `_save()` in
`log_activity_sheet.dart`: if `start`, `end`, or `goalId` was unset when
SAVE ENTRY was tapped, the whole write was skipped **silently** — no
error, and the sheet still called `reset()` + popped itself exactly as if
it had saved. Pre-existing bug (the original full-screen form had the
exact same silent-no-op guard), but the new **Day** field (see above) made
it much easier to trigger: it's now the first field, so it's easy to fill
in the day and an activity name, feel "done", and tap save without
noticing Start/End/Goal are all still empty below.

Fixed: `_save()` now builds a list of what's actually missing (day,
start/end, goal) and, if anything is, shows a SnackBar naming it and
**returns without closing the sheet** — the user can fix the specific
field and try again, instead of losing the entry with no explanation.
Only writes the `TrackedBlock` and closes once everything required is
actually present.

New widget test (`test/widget_test.dart`) fills in only the activity name,
taps SAVE ENTRY, and confirms: no exception, the sheet is still open
("Log activity" still visible), a "...before saving" message appears, and
no tracked block was created. Verified: `flutter analyze` clean, all 112
tests pass (111 + 1 new). Confirmed the app still launches cleanly on the
simulator; live tap-through to see the SnackBar itself wasn't achieved
this round either (see **Known environment quirks**) — relying on the
widget test, which does directly assert the SnackBar's text appears.

**Follow-up: broader test coverage for the log flow**, per the user's
explicit ask after confirming the repro (their case was specifically "the
goal was empty"). Five more tests, all in `test/widget_test.dart`:
1. Start/end set, goal not picked — the exact real repro — asserts the
   message specifically says "a goal" (not the generic combined message).
2. Goal picked, start/end not set — asserts "a start and end time"
   specifically.
3. **Recovery**: trigger the goal-missing failure, then actually pick a
   goal and save again — confirms the sheet stays fully usable after a
   failed attempt rather than getting stuck.
4. Leaving the Activity name blank (day/start/end/goal all set) — the
   resulting `TrackedBlock.title` falls back to the goal's own name
   (existing `_save()` behavior, wasn't directly asserted before).
5. Closing the sheet resets the draft — pick a goal, tap "close", reopen,
   confirm no goal is selected the second time (`draftLogEntryProvider`
   is a single global provider shared across opens, so this is a real
   thing to verify, not a given).
   **Caught my own test bug while writing this one**: `_FieldLabel`
   always uppercases its text (`text.toUpperCase()`), so the field reads
   "WEEKLY TARGET" on screen — my first draft asserted `find.text('Weekly
   target')` and failed. Fixed the assertion, not the (correctly
   uppercase, by design) label.

**Separate finding, not fixed**: the log sheet's **Note** field
(`draft.note`, set via `notifier.setNote`) is captured in
`DraftLogEntryProvider` state but never actually used anywhere —
`TrackedBlock` has no `note` field at all, so whatever the user types
there is silently discarded on save. Same class of bug as the one just
fixed (input captured, then dropped with no feedback), but out of scope
for this round — flagged to the user rather than fixed unasked, since it
needs a model field + Firestore schema change + a place to actually show
the note, not just a validation tweak.

Verified: `flutter analyze` clean, all 117 tests pass (112 + 5 new).

## Activities list: goal name next to each entry, tappable (fifth session)

Ask: show which goal each activity counts toward, right next to its name
in the Activities list, and make it open that goal.

- **`TrackedBlock` doesn't store a goal id** — only `categoryId` (logging
  is goal-first in the UI, but the block itself only ever remembered the
  category the selected goal resolved to). So showing "which goal" means
  working backwards from the category, same as the app already did once
  before (for the old "counts toward X" line while logging, since
  removed). Added a fresh, **live** `goalForCategory(goals, categoryId)`
  in `goals_providers.dart` (takes an already-watched `goals` list, same
  style as `_actualHoursForGoal`/`_plannedHoursForGoal` in that file) —
  and deleted the old dead `goalForCategory` in `data/mock/mock_goals.dart`,
  which iterated the static `mockGoals` constant and had zero callers left
  anywhere in the app (confirmed by grep before removing it).
- **`_ActivityRow`** (`activities_screen.dart`) now takes a `Goal?` and an
  `onTapGoal` callback. When the category resolves to a goal, its name
  renders right after the activity title (accent-colored, same inline-link
  language as "EDIT"/"close"/"categories" elsewhere in this app) and
  tapping it opens that goal's own detail sheet
  (`showGoalDetailSheet`) — no label at all when the category doesn't
  back any goal (e.g. a goal deleted after the fact), rather than a dead
  link.
- Two new widget tests: tapping the goal label next to a known block opens
  `GoalDetailSheet` (needed `ensureVisible` first — same off-screen-tap
  issue hit earlier for SAVE ENTRY, now a recurring pattern worth
  remembering for any button below the fold in a scrollable list/sheet);
  and — built via the same on-the-fly Firestore-seeding-then-mutate
  pattern used for the "complete" button test — deleting a goal after
  seeding confirms its category's activities still render with no goal
  label and nothing tappable, rather than a broken link. Verified:
  `flutter analyze` clean, all 119 tests pass (117 + 2 new).

## Onboarding: first login after sign-up prompts goal creation (fifth session)

Ask: a brand-new account should be prompted to create the goals it wants
to track, starting from 5 predefined categories (Work – blue, Exercise –
green, Leisure – light blue, Art – purple, House cleaning – dark purple).

- **`lib/data/onboarding_categories.dart`** (new) — the 5 `Category`
  objects, fixed ids (`onboarding-work` etc., not generated) so re-seeding
  is idempotent rather than creating duplicates. Colors computed the same
  way every other category color in this app is (`oklch(0.58 0.19 <hue>)`,
  see `theme/app_category_colors.dart`) — verified by rendering the exact
  same OKLCH inputs the existing colors came from onto a `<canvas>` in a
  scratch browser tab and confirming the sRGB output matched the existing
  hex constants exactly, before trusting the two new ones:
  - Work: hue 255 → `#0278E7` (already the app's existing "blue").
  - Exercise: hue 145 → `#009520` (already the app's existing "green").
  - Leisure: hue 230 → `#0089D3`, a new hue between the existing teal (200)
    and blue (255) — "light blue" is its own distinct hue, not just a
    lighter version of an existing one, so it gets its own like every
    other category does.
  - Art: hue 300 → `#8E57D8` (already the app's existing "purple").
  - House cleaning: **same hue 300 as Art**, but lightness dropped to
    0.42 → `#6022A2` — the one deliberate departure from the
    fixed-lightness rule every other category color follows, because
    "dark" specifically asked for a darker shade of the *same* color
    family, not a different color; changing hue alone can't express
    "darker," only "different."
- **`lib/features/onboarding/onboarding_screen.dart`** (new) —
  `OnboardingScreen`: seeds the 5 categories once (in `initState`, via
  `WidgetsBinding.instance.addPostFrameCallback` — Riverpod forbids
  writing a provider from `initState` itself directly, same pattern
  already used for the log sheet's default-day seeding) **only if
  categories are currently empty**, so a user who deletes one of these
  later (while still having zero goals, so this screen shows again)
  doesn't get it silently resurrected. Shows a welcome message and the
  *live* category list (not the static seed constant — matters for an
  account that already has its own non-predefined category and zero
  goals, so it sees what's actually there rather than 5 chips for
  categories that may not exist) as tappable chips; tapping one opens the
  existing goal-creation sheet pre-scoped to that category.
- **`showGoalEditSheet`/`GoalEditSheet`** (`goal_edit_sheet.dart`) — new
  optional `initialCategoryId` param (ignored when editing, only applies
  when creating) so a category chip can open goal creation pre-scoped to
  itself, reusing the entire existing goal form rather than building a
  parallel one for onboarding.
- **No "done"/"skip" button** — creating a goal *is* what ends onboarding,
  reactively: `AuthGate` (see below) watches the same live goals list this
  screen writes through, so the moment a goal exists it swaps to the real
  app on its own. Further goals after that go through the normal Goals
  tab exactly as before; nothing else needed to "finish."
- **`lib/features/auth/auth_gate.dart`** — new `_SignedInGate`, inserted
  between "signed in" and `RootShell`: shows `OnboardingScreen` while the
  account's goals are empty, `RootShell` otherwise. Waits for both the
  goals *and* categories streams' first snapshot (`.hasValue`) before
  deciding — critical, since a naive check on the resolved-empty list
  would flash onboarding at a **returning** user with real goals for the
  one frame before their first Firestore snapshot arrives.
- **Test fallout**: this is a real behavior change — a freshly signed-in
  empty account no longer reaches `RootShell` directly, it reaches
  `OnboardingScreen`. Three existing tests assumed the old behavior and
  needed fixing, not just relabeling:
  - Two `login_screen_test.dart` tests asserted `RootShell` after a fresh
    sign-in; updated to expect `OnboardingScreen` instead, plus one new
    test confirming an account that already has a goal skips straight to
    `RootShell`.
  - Two `widget_test.dart` tests exercised the "create a category first"
    guard using a totally empty account — now unreachable through the
    normal signed-in flow, since onboarding intercepts it first. Replaced
    their fixture with `_signedInNoCategoriesOverrides()`: one goal
    seeded (referencing a category id that doesn't exist), zero
    categories — the actually-reachable real version of this state (every
    category deleted after the fact, orphaning a goal that survives) —
    still hits the guard, without going through onboarding first.
  - One `widget_test.dart` test (`Activities` empty-state) used the same
    totally-empty fixture; replaced with
    `_signedInOnboardedNoActivityOverrides()` (one category, one matching
    goal, zero blocks) — the realistic "just finished onboarding, hasn't
    logged anything yet" state, which is arguably a *better* test of that
    empty-state message than the old one.
  - Old `_signedInEmptyOverrides()` (now unused everywhere) removed
    rather than left dead.
- Four new tests in `test/features/onboarding/onboarding_screen_test.dart`:
  seeding produces exactly the 5 categories and their chips; tapping a
  chip opens `GoalEditSheet` with that category already selected; creating
  a goal through it lands in `RootShell` with the right goal/category
  saved; and an account with its own pre-existing category doesn't get
  the predefined 5 silently re-added.
- Verified: `flutter analyze` clean, all 124 tests pass. Live-verified
  that an **existing** account (real Firebase data, a "Walking" goal
  already tracked) correctly skips onboarding and reaches the normal Day
  view — confirms the "existing account bypasses onboarding" half of this
  live, not just in tests. Could not live-verify the brand-new-account
  onboarding screen itself this round — would need a fresh sign-up
  through the login form, and simulator taps have been unreliable all
  session (see **Known environment quirks**) — relying on the 8
  onboarding-specific widget tests instead, which do directly exercise
  seeding, the chip tap, goal creation, and the reactive swap into
  `RootShell`.

## Onboarding follow-up: 3 more categories + descriptions (fifth session)

Two quick rounds right after the onboarding feature above:
1. Added **Sleep** — a deliberately darker indigo (`oklch(0.45 0.19 275)`
   → `#3D3FBB`) for a "night" feel, same reasoning as House cleaning's
   dark purple: the descriptor asked for a mood/shade, not just a new hue.
2. Proposed 3 more via `AskUserQuestion` (with rendered color previews) —
   user picked all three, generalizing "Admin / Finance" to plain
   **Admin**: **Social** (`oklch(0.58 0.19 20)` → `#D33949`), **Learning**
   (`oklch(0.58 0.19 340)` → `#BE409D`), **Admin** (`oklch(0.58 0.19 70)`
   → `#BE5D00`). `onboardingCategories` is 9 long now.

Also asked for a one-line description on every predefined category. This
is **onboarding UI copy, not a `Category` model field** — deliberately:
adding a `description` to `Category` would mean a Firestore schema change,
`toMap`/`fromMap` updates, and a place to show/edit it for every
user-created category too (Categories screen, `category_edit_sheet.dart`)
— a much bigger, differently-scoped change than "explain what these 9
predefined ones mean." Instead, `onboardingCategoryDescriptions` in
`data/onboarding_categories.dart` is a plain `Map<String, String>` keyed
by the same fixed category ids, purely for `OnboardingScreen`'s own
display.

With 9 categories (up from 5) and real description text per one, the
original `Wrap` of compact `CategoryChip`s no longer read well — replaced
with a scrollable `Column` of full-width rows (`_CategoryOption`: colored
left bar + name + description, same visual language as the Activities
list's own rows), each tappable to open goal creation pre-scoped to that
category, same as before.

Test fallout: the existing onboarding tests hardcoded the 5-category
list; rewrote the seeding test to assert against `onboardingCategories`
itself (so it stays correct as more get added, rather than needing
another manual update) and added a check that every category's
description actually renders. The chip-tap tests just needed their tapped
text updated from the old lowercase chip label (`'exercise'`) to the new
row's proper-case name (`'Exercise'`) — `GoalEditSheet`'s own internal
category chips are untouched by this and still lowercase, so those
assertions didn't change. Verified: `flutter analyze` clean, all 124
tests pass (same count as before — edits to existing tests, not new
ones). Confirmed the app still launches cleanly on the simulator, and
that an existing account still correctly bypasses onboarding.

## Removed the cap goal type entirely (fifth session)

User asked what "cap" meant, then said to remove it — confirmed via
`AskUserQuestion` that this meant removing `GoalType.cap` from the app
entirely (every goal becomes a target/minimum; no ceiling-type goals at
all), not just narrower changes like dropping it from onboarding/mock
data. Ran a full-codebase scan first (an `Explore` agent) to get a
complete inventory before touching anything, since a partial removal
would leave dangling `GoalType`/`GoalStatus.overCap` references.

Since every goal is a target now, **`GoalType` and `Goal.type` are gone
from the model entirely** — not narrowed to a single-value enum. A field
that can only ever hold one value carries no information, so keeping it
"for future flexibility" would just be complexity with no current
purpose (re-add if a real second type ever comes back).

- **`lib/models/goal.dart`** — `enum GoalType` and the `Goal.type` field
  deleted, including `toMap`/`fromMap`. **No migration needed**: existing
  Firestore goal docs still have a `type` key from before this change;
  `fromMap` just doesn't read it anymore, so it sits there unused and
  harmless (confirmed live — the real account's existing goals still
  loaded fine after this change, built and launched on the simulator with
  no crash).
- **`lib/models/goal_progress.dart`** — `GoalStatus.overCap` removed
  (just `{onPace, behindPace}` now); `computeGoalProgress` no longer
  branches on goal type, always uses the on/behind-pace logic; the
  `formatGoalStatus` `overCap` case (the "over cap by Xh Ym" text) gone.
- **`lib/models/goal_planned_blocks.dart`** — the `goal.type !=
  GoalType.target` filter removed; every active goal's time-range entries
  generate a planned block now, not just target-type ones.
- **`lib/models/goal_completion.dart`** — the cap early-return in
  `pendingPlannedBlocksForGoal` removed; the "complete" button is now
  offered for every goal with something pending, not gated by type.
- **`goal_edit_sheet.dart`** — the Target/Cap `SegmentedControl` toggle
  removed from the create/edit form entirely, along with the `_type`
  state field and its two write sites.
- **`goal_block.dart`, `goal_detail_sheet.dart`, `week_view_screen.dart`**
  — the three `GoalStatus.overCap`-conditional accent-color/" — over"
  branches removed; status text is always the default color now.
- **`lib/data/mock/mock_goals.dart`** — the 3 cap-type mock goals
  (Meetings, Admin, Screen after 21:00) **dropped rather than converted**
  to target-type: their entire premise was "stay under this," and
  recasting that as "reach a minimum of this" would misrepresent them —
  nobody wants a minimum amount of screen time. Only Walking and Deep
  work (already target-type) remain. Also dropped `mockGoalActualHours`,
  already-dead code that only existed to key off those 3 categories.
  Real-user consequence, called out rather than silently absorbed: anyone
  who already had a real cap-type goal in their live account keeps it —
  it just reads as a target (pace-based, not ceiling-based) from now on,
  same "old field just goes unread" situation as above, not something
  this session could safely auto-migrate without knowing what's actually
  in a specific account.
- Test fallout across 5 files (`goal_progress_test.dart`,
  `goal_planned_blocks_test.dart`, `goal_completion_test.dart`,
  `widget_test.dart`, `login_screen_test.dart`): 4 cap-specific tests
  deleted outright (they tested behavior that no longer exists), every
  other `type: GoalType.target` constructor argument stripped, and two
  stale comments explaining old cap-exclusion reasoning corrected.
  Verified: `flutter analyze` clean across `lib/` and `test/`, all tests
  pass. Confirmed live on the simulator: the app still launches and the
  existing real account's pre-existing goals still load correctly.

## Day view's add-block sheet: pick a goal, editable start/end dates (fifth session)

Ask: tapping empty space in Day view should pick a goal (not a bare
category, matching the Log activity sheet's goal-first convention),
support editing both the start and end date (not just time — a block can
now span two different calendar days), and keep the activity name field.

- **`lib/shared/widgets/date_field.dart`** (new) — extracted `DateField`
  from the Log activity sheet's private `_DateField` now that a second
  real caller needs the same "bordered, tappable, opens `showDatePicker`"
  widget. `firstDate`/`lastDate` are caller-supplied rather than baked in,
  since the right bound differs by context: the Log sheet's day can't be
  in the future (you can't manually log something that hasn't happened),
  but a *planned* block in Day view reasonably can be.
- **`add_block_sheet.dart`** — `_categoryId` replaced with `_goalId`;
  category chips replaced with goal chips (same `screenTimeCategoryId`
  exclusion as the Log sheet — screen time is auto-tracked, never
  manually planned or logged); the category a saved block gets is derived
  from the picked goal, same as everywhere else goal-first logging
  already works. Added independent **Start date**/**End date** fields
  next to the existing Start/End time fields — each block's start and end
  can now land on different calendar days. The pre-existing "if end time
  isn't after start time, roll forward a day" logic stays as a safety net
  for whoever doesn't bother touching the date fields, but explicit dates
  are respected when given. The empty-account guard now checks for zero
  *goals* (via the same `screenTimeCategoryId`-excluding helper), not
  zero categories — "Create a goal first" instead of "Create a category
  first".
- Field relabeled "Title" → "Activity", matching the Log sheet's naming.
- Test fallout: the existing "no categories" guard test for Day view no
  longer describes a reachable state on its own — a zero-goal account
  never reaches Day view at all now (onboarding intercepts first, see the
  cap-removal-adjacent onboarding section above) — so it now pumps
  `RootShell` directly (bypassing `AuthGate`/onboarding) with zero goals,
  which specifically isolates `add_block_sheet`'s own guard from the
  onboarding gate. Two new tests: the full happy path (tap empty space →
  goal chips, not category chips → save → the block's category matches
  the picked goal's, not some bare category selection) and the date
  fields themselves (both default to the app's selected day
  independently, open the real native date picker without crashing,
  survive a Cancel). **Two real gotchas caught by actually running these,
  not just writing them**: the test's "today" comparison first assumed
  the real device clock (wrong — this account's fixture pins
  `selectedDateProvider` to `mockDay`, a detail easy to forget reaching
  back into much-earlier test code from the same session), and Flutter's
  stock date picker's dismiss button reads "Cancel" (Title Case), not
  "CANCEL" — worth remembering for any future test driving
  `showDatePicker` for real. Verified: `flutter analyze` clean, all 123
  tests pass. **Live-verified on the simulator this round** — a real tap
  landed and the sheet rendered exactly as built: goal chips (not
  categories), independent Start/End date fields alongside Start/End
  time, and the Activity name field.

## Goal detail sheet polish round (fifth session, several quick follow-ups)

After the date-range/per-day-target work below shipped, a few rapid
follow-up asks on the same screen:
- Per-day strip now shows that day's **actual** tracked time right under
  its target, in the same column (accent-colored, "—" for none) — a
  same-turn addition to `_TargetPerDayRow`, sharing its existing `Key`.
- "active since" → "active" (dropped "since", both dates already say what
  they mean without it).
- Reordered the sheet: the **active**/**runs** date row moved to the top
  (right after progress/status), and the **actual**/**target** weekly
  totals moved to *after* the per-day strip, so the flow reads
  active-dates → per-day detail → weekly totals, not totals-then-detail.
- **Removed decimal-hours formatting everywhere it appeared** ("12.4 h") in
  favor of the app's one existing duration format ("12 h 24") — this
  wasn't scoped to the goal detail sheet, the user asked for it site-wide.
  Added `hoursToDuration`/`formatHours` to `lib/utils/duration_format.dart`
  (composes with the existing `formatDuration`) and swapped every
  `.toStringAsFixed(1)`-style call site: `goal_block.dart` (Goals list row
  header + "planned X h"), `goal_detail_sheet.dart` ("actual" stat row),
  `week_view_screen.dart` (goals footer), `log_activity_screen.dart`
  ("Weekly target"), and `capacity_screen.dart` (every figure — totals,
  per-day free/overplanned, per-goal room). Unit-tested directly
  (`test/utils/duration_format_test.dart`), including the literal reported
  bug ("12.4 h" → "12 h 24 m" — the "12 h 24" first pass was still missing
  the trailing "m" the user then caught, see next bullet).
- **`formatDuration` itself was missing "m" on the minutes part whenever
  hours were also shown** — "1 h 45" instead of "1 h 45 m" (minutes-only
  durations like "45 m" were always correct; only the combined case was
  short). This is the one shared function nearly every duration/hours
  display in the app goes through, so fixing it here fixed it everywhere
  at once — including two duplicate reimplementations that had copy-pasted
  the same gap: a private `_formatHours` in `models/goal_progress.dart`
  ("over cap by X" messages) and a private `_hoursToDuration` in
  `week_view_screen.dart`, both now deleted in favor of importing the one
  shared version from `utils/duration_format.dart`. Every test asserting
  an exact old-format string ("1 h 45", "2 h 35 untracked", "3 h 30 this
  week", ...) needed updating to match — a reminder that hardcoding a
  shared format function's exact output string in many tests makes any
  future format tweak touch all of them; not changing that pattern now,
  just noting it. (Prediction confirmed almost immediately: the very next
  ask was to drop the space between a number and its unit letter too —
  "1h 45m" not "1 h 45" — which touched the same ~15 test assertions
  again. Two rapid rounds of the same "shared format function changed"
  cost is exactly the reminder above playing out, not a new lesson.)

## Goal detail sheet: date range and per-day targets (fifth session)

Two more real gaps the user found by using the app, both in
`goal_detail_sheet.dart`:

1. **Date range was hidden for ongoing goals.** The "runs: start – end"
   stat row only ever rendered `if (progress.goal.isDateBound)` — but most
   goals are *not* date-bound (the default end date is ~1 year out, read as
   "ongoing" per `Goal.isDateBound`/`ongoingGoalSpan`), so for the common
   case the date range was never shown at all, which the user flagged.
   First fix: always show a row, but only the start date for an ongoing
   goal (label `active since`), reasoning that the stored end date is just
   an implementation detail (~1 year out) and showing it as a real range
   would misrepresent an open-ended habit. The user then asked explicitly
   for both dates in that one row anyway — so `active since` now shows
   `start – end` too, same format as the date-bound `runs` row, just under
   a different label. (The "don't show a fake end date" reasoning above is
   now moot per the user's explicit ask — noted here so a future session
   doesn't "fix" it back.)
2. **Only today's target was shown, not the full week's breakdown.** The
   "target" stat row read like "3 h 30 this week · today 30 m" — accurate,
   but for a goal like "Walking / varies by day" there was no way to see
   *how* it varies without opening the edit sheet. Added `_TargetPerDayRow`
   — a compact 7-day strip, right under the target stat row — with each
   day's own target, and (per a same-session follow-up ask) that day's own
   actual tracked time right below it in the same column (accent-colored,
   "—" for no activity). Gave the row a `Key('goalDetailTargetPerDayRow')`
   purely for test-scoping — its per-day durations are identical in
   substance to each block's own duration shown separately in "ACTUAL THIS
   WEEK" below, so unscoped `find.text(...)` in tests kept finding both and
   double-counting.
3. **The "planned" stat row was removed** (was `planned: X h`, right above
   "actual") — the user asked for it gone; `progress.plannedHours` is still
   computed and used elsewhere (the progress bar, the Goals list row's own
   "planned X h" text, the Capacity page), only this one display row went
   away.

Widget tests cover all three (`test/widget_test.dart`): one confirming
`active since` (not `runs`) shows the full `start – end` range for an
ongoing goal, one confirming all 7 day labels and the correct per-day
target values (Walking: 5× "1 h" for Mon–Fri, 2× "2 h 30" for Sat–Sun, per
`mock_goals.dart`). Verified: `flutter analyze` clean, the full suite (88
tests) passes. Live tap-through wasn't achieved on the simulator this round
either (documented flakiness, see **Known environment quirks**) — same
fallback as before, relying on the widget tests' precise finders.

## Goal edit sheet: barrier-tap and Save/Discard/Keep (fifth session)

The fourth session's unsaved-changes guard (see below) disabled the goal
edit sheet's barrier tap entirely (`isDismissible: false`) so it could
force every exit through a guarded "cancel" link — but that meant tapping
outside the sheet just did nothing (a denied-tap system beep, no visible
reaction), which the user flagged as a real bug. Also asked for a third
option: save directly from the close prompt, not just discard/keep
editing, and for "cancel" to read "close" instead.

Fixed by actually reading how Flutter's bottom sheet barrier dismissal
works (`ModalBarrier.onDismiss`, `packages/flutter/lib/src/widgets/
modal_barrier.dart`) rather than guessing: a barrier tap with
`isDismissible: true` (the default) calls `Navigator.maybePop`, which
**does** respect `PopScope.canPop` — unlike a direct `Navigator.pop()`
call, which bypasses it entirely (confirmed the same way while building
the original guard). So `isDismissible: false` was never necessary for the
barrier — only `enableDrag: false` still is, since a completed
swipe-to-dismiss goes through `BottomSheet.onClosing`, which calls
`Navigator.pop()` directly inside Flutter's own code, with no hook to
intercept it. Now:
- `isDismissible` is back to its default (`true`) — a barrier tap goes
  through the same `PopScope` guard as everything else, so it now prompts
  when there are unsaved changes, instead of doing nothing.
- The close prompt (`_UnsavedChangesDialog`, was `_DiscardChangesDialog`)
  has three options now: **SAVE** (calls the sheet's own `_save()`),
  **DISCARD**, **KEEP EDITING** — via a new `_ExitAction` enum rather than
  the old `bool`.
- "cancel" renamed to "close" (the link text, and internally
  `_handleCancel` → `_handleClose`).

Five new/updated widget tests cover this — closing with no changes (no
prompt), closing with changes → Keep editing, → Discard, → Save, and a new
test specifically simulating a barrier tap (`tester.tapAt` near the top of
the screen, above the sheet) to confirm that path prompts too.

## Capacity page (fifth session)

New page off the Week view, answering something the existing Week view
never did: "how much is planned, and how much is still available." The
existing Week view already covers plan vs actual (per-day stacked bars,
weekly totals, drift, a goals-vs-actual footer) — this page adds the
missing "available" dimension rather than duplicating any of that.

- **`lib/models/day_capacity.dart`** — `DayCapacity` (pure value class) +
  `computeDayCapacity`, unit-tested in
  `test/models/day_capacity_test.dart`. "Available" is computed against an
  11-hour window (07:00–18:00), reusing `dayWindowFor` from
  `state/derived_providers.dart` — the same window the Day view already
  uses to decide what counts as "untracked," so a day being "fully booked"
  means the same thing in both places rather than introducing a second
  definition. A day planned past the window reports `overplannedHours`
  instead of `availableHours` going negative.
- **`state/week_view_providers.dart`** — new `weekDayCapacityProvider`,
  derived from the existing `weekDaySummariesProvider` (same planned/actual
  totals already shown elsewhere in the Week view, just paired with the
  capacity math). No change to what "planned" means — still whatever
  `weekDaySummariesProvider` already counted before this page existed.
- **`lib/features/week_view/capacity_screen.dart`** — `CapacityScreen`,
  pushed via `showCapacityScreen`, linked from a new "capacity" link in the
  Week view's stats row. Two sections: **free time per day** (a day
  row per weekday — solid bar for planned, hatched for available, "over by
  X h" instead of a negative number when overplanned) and **room toward
  goals** (reuses `goalProgressListProvider` directly — each goal's
  `plannedHours` vs `goal.weeklyTargetHours`, no new provider needed for
  this half).
- Two new widget tests: the full open → verify both sections → close flow,
  and a dedicated overplanned-day scenario (12h manually planned into an
  11h window) confirming "over by" appears instead of a nonsensical
  negative "available" figure.
- Verified: `flutter analyze` clean, this session's tests pass, and the
  "capacity" link visually confirmed rendering correctly on the iOS
  Simulator (styled, in the right place) — the screen's actual content
  wasn't visually confirmed live past that, since tap coordinates have
  been unreliable in this environment all project (see **Known environment
  quirks**); relied on the passing widget tests instead, which do
  precisely exercise open → both sections' content → close.

## Goal & logging UX fixes (fourth session)

Five independent fixes the user asked for after testing the app for real,
each with its own tests. All verified: `flutter analyze` clean, all 77
tests pass, plus a live spot-check on the iOS Simulator against the user's
real signed-in account (items 2, 4, 5 visually confirmed; item 3 relies on
its widget tests since live taps have been unreliable in this environment
all project — see **Known environment quirks**).

1. **Time-range end defaults to start + 30 min.** Previously both the start
   and end time pickers in a goal's "+ time range" flow defaulted to fixed
   clock times (09:00 / 17:00) independent of each other. Now the end
   picker's initial suggestion is the picked start time + 30 minutes.
   Extracted the `TimeOfDay` math both `goal_edit_sheet.dart` and
   `add_block_sheet.dart` needed into `lib/utils/time_of_day_utils.dart`
   (`addMinutes`) rather than leaving it duplicated — `add_block_sheet.dart`
   already had its own private copy. Unit-tested directly in
   `test/utils/time_of_day_utils_test.dart`.

2. **Plain-duration goal entries are never auto-placed on the calendar.**
   `generateGoalPlannedBlocksForDate` (`lib/models/goal_planned_blocks.dart`)
   used to greedily place duration-only entries ("piano, 15 min, any time")
   into free calendar slots, marked `isGoalAutoPlaced`. That whole placement
   path is gone — only time-range entries (a real clock time) ever generate
   a `PlannedBlock` now; a plain duration only ever counts toward the
   goal's weekly target, never appears on the Day view. This let
   `PlannedBlock.isGoalAutoPlaced` be deleted entirely (model, `toMap`/
   `fromMap`, and the "· auto-placed" label in `goal_detail_sheet.dart`) —
   it's now permanently false everywhere, since nothing sets it anymore.
   `generateGoalPlannedBlocksForDate`'s signature also simplified — it no
   longer takes `existingBlocksForDate` (that was only ever used for the
   now-deleted overlap-avoidance logic). Rewrote
   `test/models/goal_planned_blocks_test.dart` for the new behavior (two of
   its old tests, about duration-entry overlap placement, no longer apply
   to anything and were removed rather than adapted).

3. **Unsaved-changes confirmation when exiting the goal edit sheet.**
   `GoalEditSheet` now snapshots its initial field values on open (via
   `Goal.toMap()` + `package:collection`'s `DeepCollectionEquality`, rather
   than adding `==`/`hashCode` to the model just for this) and compares
   against that snapshot whenever something tries to close the sheet. If
   nothing changed, it closes immediately, same as before — this applies
   equally whether creating a new goal or editing an existing one, not
   just editing (didn't seem worth having two different behaviors for the
   same sheet). If something changed, a flat, on-brand "Discard changes?"
   dialog (`_DiscardChangesDialog`, no `AlertDialog` — Material's default
   has rounded corners) asks first. The sheet's barrier-tap and
   swipe-to-dismiss are now disabled (`isDismissible: false, enableDrag:
   false`) so the "cancel" link is the only exit path to guard — wrapped in
   `PopScope(canPop: false, ...)` too, which costs nothing now (a direct
   `Navigator.pop()` call, which is all "cancel"/Save use, bypasses
   `canPop` entirely — confirmed by reading Flutter's own `Navigator.pop`
   source before relying on this) and will matter once Android ships,
   where the hardware back button *does* go through `canPop`.

4. **Logging an activity picks a goal, not a category.** The Log activity
   screen's chip row used to list categories directly
   (`draftLogEntry.categoryId`); now it lists goals
   (`draftLogEntry.goalId`, in `lib/state/log_entry_providers.dart`), each
   chip still colored by its own category
   (`resolveCategory(categories, goal.categoryId).color`) via the same
   reusable `CategoryChip` widget. The tracked block's `categoryId` on save
   is derived from the selected goal. The old "Counts toward" read-out
   (which looked up a goal *from* the picked category) is gone since
   picking the goal directly makes it redundant — replaced with a "Weekly
   target" line showing the selected goal's own `weeklyTargetHours`, which
   is new information rather than restating the selection. **Real
   consequence**: a category with no goal of its own can no longer be
   logged against directly — you now need a goal, not just a category, to
   log time. Confirmed intentional via the new
   `Categories: a new category needs a goal of its own before it shows up
   as a Log activity chip` test, which walks the full chain (create
   category → not loggable yet → create a goal for it → now loggable).
   Screen-time stays excluded from the picker either way (it's
   auto-tracked, never manually logged) — same exclusion, now expressed as
   `goals.where((g) => g.categoryId != screenTimeCategoryId)` instead of
   filtering categories directly.

5. **Planned blocks are colored by category.** `PlanBlockWidget`
   (`lib/features/day_view/widgets/plan_block_widget.dart`) used a flat
   neutral gray dashed border for every planned block regardless of
   category — `ActualBlockWidget` already colored tracked blocks by
   category, planned blocks just never got the same treatment. Now takes a
   required `category` param (same pattern as `ActualBlockWidget`) and
   uses `category.color` for its dashed border. Applies to every planned
   block (manual and goal-generated alike), not just goal-originated ones,
   since there's only one `PlanBlockWidget` either way.

## GitHub Actions CI

`.github/workflows/ci.yml`, two jobs, triggered on push/PR to `main`:
- **`analyze-and-test`** (ubuntu-latest) — `flutter analyze` + `flutter
  test`, the same gate as local development.
- **`build-ios`** (macos-latest) — `flutter build ios --release
  --no-codesign`, to catch iOS/Xcode-project breakage analyze+test alone
  can't see. Unsigned on purpose — CI has no access to the team's signing
  identity, so it can't produce something installable; it only proves the
  code and Xcode project are in a buildable state.

Not yet pushed (this session's work is uncommitted — see **Git status**).
Once pushed, this needs no further setup — no secrets, no self-hosted
runner, nothing Firebase-related (tests run entirely against
`fake_cloud_firestore`/`firebase_auth_mocks`, never the real project).

## Installing on a physical iPhone

Confirmed ready on the code side — `flutter build ios --release
--no-codesign` succeeds (`Built build/ios/iphoneos/Runner.app`, arm64
device build, not simulator), bundle id `com.drivector.calendarTracker`
matches between the Xcode project and `ios/Runner/GoogleService-Info.plist`
(so Firebase will actually work on-device), deployment target iOS 15.0
(fine for any modern iPhone). **The only remaining step is code signing**,
which needs the user's own Apple ID inside an interactive Xcode session —
not something achievable from this CLI environment, and not something I
should do even if it were (entering Apple ID credentials on the user's
behalf is out of bounds). Steps for the user:
1. Open `ios/Runner.xcworkspace` in Xcode (the `.xcworkspace`, not
   `.xcodeproj` — CocoaPods/SPM dependencies need the workspace).
2. Runner project → Runner target → **Signing & Capabilities** tab → set
   **Team** to your personal Apple ID (Xcode → Settings → Accounts to add
   it first, if it's not there yet). Leave "Automatically manage signing"
   checked.
3. Connect the iPhone via USB (or same-network wireless debugging once
   paired once), unlock it, tap "Trust This Computer" if prompted.
4. Pick the connected iPhone from Xcode's device dropdown (top toolbar),
   then hit Run (▶). First launch needs one more trust step *on the
   iPhone*: Settings → General → VPN & Device Management → select the
   developer profile → Trust.
5. **A free (non-paid) Apple ID's signing expires after 7 days** — Xcode
   will need to re-sign (just hit Run again) weekly. A paid Apple Developer
   Program membership ($99/yr) removes that limit and also unlocks
   TestFlight, if that's ever wanted instead of a cable-tethered install.
6. After the one-time Xcode signing setup, `flutter run --release -d
   <device-id>` from `app/` works directly too, if CLI is preferred over
   clicking Run in Xcode each time.

## Authentication + Firestore backend

Real sign-up/login via **Firebase Auth** (email/password), plus **all
in-memory mock data replaced with Firestore**, scoped per account — this is
now built and tested, gated only on the user finishing Firebase console
setup (see **Not yet done**).

### What's built
- **`lib/features/auth/login_screen.dart`** — email/password sign-in and
  sign-up in one screen (toggle link between the two modes), Modernist
  styling, friendly error messages mapped from `FirebaseAuthException.code`.
- **`lib/features/auth/auth_gate.dart`** — `AuthGate` watches
  `authStateChangesProvider`; shows `LoginScreen` when signed out,
  `RootShell` when signed in, a loading state in between. Wired in as
  `app.dart`'s `home:` (was `RootShell` directly).
- **Sign out** — a "sign out" link next to "categories" in the Goals screen
  header (`goals_screen.dart`) — there's no dedicated settings screen yet,
  this was the simplest existing entry point.
- **`lib/state/auth_providers.dart`** — `firebaseAuthProvider`
  (`Provider<FirebaseAuth>`), `authStateChangesProvider`
  (`StreamProvider<User?>`).
- **`lib/state/firestore_providers.dart`** — `firestoreProvider`
  (`Provider<FirebaseFirestore>`), `currentUidProvider` (`Provider<String>`,
  force-unwraps the signed-in uid — only ever watched from inside
  `RootShell`'s subtree, which `AuthGate` only mounts once signed in).
- **`lib/data/firestore/firestore_list_repository.dart`** —
  `FirestoreListRepository<T>`, the shared shape behind all four
  collections: `watchAll()` (live stream), `upsert(item)` (create-or-replace
  by id), `remove(id)`. Backs `categoriesRepositoryProvider`,
  `goalsRepositoryProvider`, `plannedBlocksRepositoryProvider`,
  `trackedBlocksRepositoryProvider` (one per collection, defined alongside
  each domain's other providers in `state/categories_providers.dart`,
  `state/goals_providers.dart`, `state/day_view_providers.dart`).
- **Firestore document shape** — `users/{uid}/categories/{id}`,
  `.../goals/{id}`, `.../plannedBlocks/{id}`, `.../trackedBlocks/{id}`, one
  doc per item, id-keyed. `toMap()`/`fromMap()` added to `Category`, `Goal`
  (incl. `DayScheduleEntry`), `PlannedBlock`, `TrackedBlock` for
  serialization — see those model files.
- **Existing `categoriesProvider`, `goalsProvider`, `allPlannedBlocksProvider`,
  `allTrackedBlocksProvider` provider names/shapes are unchanged** (still
  plain `Provider<List<X>>`, not `AsyncValue`) — each is now
  `streamProvider.valueOrNull ?? []` under the hood, so no consuming widget
  needed to change. Only the **write** call sites changed, from
  `ref.read(xProvider.notifier).addX(...)` to
  `ref.read(xRepositoryProvider).upsert(...)` (and `.remove(id)` for
  deletes) — 9 call sites across `goal_edit_sheet.dart`,
  `category_edit_sheet.dart`, `add_block_sheet.dart`,
  `log_activity_screen.dart`.
- **Seed-data decision (asked the user explicitly)**: a brand-new account
  starts **completely empty** — no goals/categories/blocks. This meant two
  real bugs to fix: `add_block_sheet.dart`'s and `goal_edit_sheet.dart`'s
  "new item" flows both defaulted `categoryId` to `categoriesProvider.first`,
  which throws on an empty list — both now no-op (don't open the sheet) if
  there are no categories yet, since there's nothing sensible to default to.
  There's no other empty-state messaging anywhere in the app yet (Day view,
  Goals, etc. all just render nothing) — that's a legitimate follow-up if
  onboarding UX is wanted, out of scope for this session.
- **`_actualHoursForGoal` in `goals_providers.dart` had its mock-baseline
  hack removed** — it used to add a hardcoded `mockGoalActualHours` constant
  on top of real tracked-block hours (a workaround for the old seeded mock
  data not being distinguishable from real activity). Now that a real
  account has no seed data to begin with, it just sums real tracked blocks
  for the week — this is a genuine behavior fix, not just a refactor
  side-effect.
- **`selectedDateProvider` now defaults to today's real date**
  (`DateTime.now()`, date-only) instead of the hardcoded mock day (20 Aug
  2026) — tests that relied on the old default now explicitly override it
  to `mockDay` (see **Testing** above).
- **`goalForCategory`** (shown as "counts toward X" while logging an
  activity) used to read the hardcoded `mockGoals` constant regardless of
  the app's real state — moved to `goals_providers.dart` as a plain function
  over a live `List<Goal>`, called from `log_activity_screen.dart` with
  `ref.watch(goalsProvider)`.
- **Firestore config**: `firestore.rules` (every collection under
  `users/{uid}/{collection}/{docId}`, readable/writable only by that uid),
  `firestore.indexes.json` (empty), `firebase.json` updated with a
  `"firestore"` block, `.firebaserc` pins the `trackmyday-6380a` project as
  default. **Not yet deployed** — see **Not yet done**.
- Verified: `flutter analyze` clean, all 73 tests pass, `flutter build macos
  --debug` succeeds and the built app launches and stays running (with
  `Firebase.initializeApp()` against the real `trackmyday-6380a` project) —
  confirms the macOS App Sandbox's existing `network.client` entitlement
  (already present in both `DebugProfile.entitlements` and
  `Release.entitlements`) is sufficient for Firebase's network calls, no
  entitlement changes needed.

### Firebase project setup completed (this and prior session)
- Node.js, `firebase-tools` v15.28.1, `flutterfire_cli` v1.4.1 all installed
  and confirmed working; user logged in to the Firebase CLI; Firebase
  project created (display name "TrackMyDay", project ID `trackmyday-6380a`).
- `flutterfire configure --project=trackmyday-6380a --platforms=ios,macos`
  run this session — registered the iOS + macOS apps, generated
  `lib/firebase_options.dart`, `ios/Runner/GoogleService-Info.plist`,
  `macos/Runner/GoogleService-Info.plist` (all now in the repo).
- `firebase_core`, `firebase_auth`, `cloud_firestore` added to
  `pubspec.yaml` and resolved.

### Firebase console setup — done
- **Email/Password sign-in** enabled by the user.
- **Firestore database created and rules deployed.** Location is
  **`nam5` (US multi-region)**, not the `europe-west3` originally agreed —
  see the incident note below for why, and note this is now **permanent**
  (Firestore location can't be changed without deleting and recreating the
  database). Confirmed via:
  ```bash
  export PATH="/opt/homebrew/bin:$HOME/.npm-global/bin:$PATH"
  firebase firestore:databases:get "(default)" --project trackmyday-6380a
  ```
- Rules are live: `firebase deploy --only firestore:rules --project
  trackmyday-6380a` completed successfully this session.

**Incident note**: running that same `firebase deploy --only
firestore:rules` command is what actually created the `(default)` database
— its output included "Creating the new Firestore database (default)...".
The user had created a database via the console shortly before (intending
`europe-west3`/`europe-west8`), but `firebase firestore:databases:list`
kept 403ing as if no database existed, for longer than ordinary propagation
lag — the console-created database apparently hadn't actually registered
server-side. When the rules deploy ran its own "ensure database exists"
step, it won the race and created a fresh one in Firestore's fallback
location (`nam5`) before the console one showed up. Asked the user how to
handle it (delete-and-recreate correctly vs. keep); **they chose to keep
`nam5`**. Lesson for next time: check
`firebase firestore:databases:get "(default)"` explicitly for an existing
database *before* running any command that might auto-create one (`deploy`,
`firestore:databases:create`), rather than assuming a 403 means "not
created yet" when it could mean "still propagating."

### Live-verified — the user signed up and used the app for real
The user tested sign-up on the iOS Simulator (built via `flutter build ios
--debug --simulator`, installed with this environment's iOS Simulator
`launch` tool — **the simulator had an old pre-auth build installed from an
earlier session**, which is why login didn't initially appear; a fresh
build fixed it). Confirmed working end-to-end: created a category, created
a "Walking" goal, data genuinely persists in Firestore (visible in a later
screenshot showing real data on the real current date, not the old
hardcoded `mockDay`), Auth session persists across app restarts (expected
Firebase behavior, not a bug — a fresh login is only forced by explicit
sign-out). Have **not** yet tested a second account to confirm data
isolation between users.

### Bug found and fixed this session: "create a category first" message
The user found that trying to create a new goal with zero categories did
nothing (silent no-op, from the guard added when "start empty" was
decided) — asked for an actual message instead. Fixed by adding a SnackBar,
which surfaced a **real crash bug**: this app has **zero `Scaffold`
widgets** anywhere (deliberately, per the Modernist system), and
`ScaffoldMessenger.showSnackBar` unconditionally asserts a descendant
`Scaffold` exists — regardless of `SnackBarBehavior.floating` vs `.fixed`,
contrary to what might be assumed. Fixed by swapping `app.dart`'s root
`Material` wrapper for a bare `Scaffold` (`home: Scaffold(backgroundColor:
AppColors.bg, body: SafeArea(child: AuthGate()))`) — one Scaffold for the
whole app, no visible chrome (no appBar/FAB/drawer), which is all
`ScaffoldMessenger` needs. `snackBarTheme` added to `app_theme.dart` (flat:
zero radius, no elevation, dark background/light text matching the
design system). Applied to both no-category guards (goal creation in
`goal_edit_sheet.dart`, day-view tap-to-create in `add_block_sheet.dart`).
Two new widget tests cover this (`test/widget_test.dart`, the two
"...with no categories..." tests) — they're what caught the Scaffold
crash in the first place.

### Not yet done — pick up here
1. Test a **second account** to confirm per-user Firestore data isolation
   (one user can't see another's categories/goals/blocks) — not yet done,
   only single-account testing so far.
2. No password-reset flow, no email verification requirement, no
   Google/Apple sign-in — email/password only, matching what was asked for.
   Worth asking the user if any of those are wanted before considering auth
   "done."

## Known environment quirks

- **iOS Simulator tap coordinates have been unreliable all session** — taps
  frequently land on the wrong element or register nothing, even after
  restarting the app/simulator, with no root cause found. When verifying UI
  changes, prefer precise widget tests (`find.descendant`, checking rendered
  `Size`/`BoxDecoration` directly) over trying to screenshot-and-tap through
  the simulator — this has proven far more reliable this session.
- **No macOS screen capture available** in this environment (`screencapture`
  fails with "could not create image from display" — no Screen Recording
  permission grantable here). macOS-only features (e.g. trackpad two-finger
  swipe, which does *not* work in the iOS Simulator at all — confirmed by the
  user, since the Simulator doesn't forward real trackpad gestures to the
  guest app) can only be verified by the user directly, not by me. The macOS
  build itself (`flutter build macos --debug`) does compile cleanly as of
  this session.
- A stray `JIRA_PERSONAL_TOKEN` exported in `~/.zshrc` — pre-existing,
  unrelated to this project, left untouched.
