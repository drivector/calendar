# Calendar Tracker — session handoff

Updated 2026-08-24 (fifth session) — Firebase Auth + Firestore are built and
live; the fourth session added five goal/logging UX fixes, CI, and iPhone
install readiness; this session fixed a real gap in the fourth session's
own unsaved-changes work (barrier-tap did nothing instead of prompting —
see **Goal edit sheet: barrier-tap and Save/Discard/Keep** below), added a
new **Capacity** page off the Week view (see **Capacity page**), and fixed
two more real gaps the user found in the goal detail sheet — its date
range was hidden for ongoing goals, and it only ever showed today's
target, not the full per-day breakdown (see **Goal detail sheet: date
range and per-day targets**). Read this first, then verify anything
time-sensitive (git status, test count, Firebase console state) since it
may have moved on since this was written.

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
- **Log activity** — manual entry form, actually persists a `TrackedBlock` now.
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

`flutter analyze` is clean; `flutter test` currently passes **88 tests**
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

## Git status — fifth session's work is uncommitted

- The Firebase Auth/Firestore backend and the fourth session's UX
  fixes/CI are committed and pushed to `drivector/calendar` main
  (`55e84e7`, `0c6414a`). This **fifth session's** work (barrier-tap fix,
  Save/Discard/Keep, the Capacity page) is **not yet committed** — ask
  before committing/pushing, per this repo's `CLAUDE.md` (each one needs
  its own go-ahead, a prior approval doesn't carry forward).
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

## Goal detail sheet: date range and per-day targets (fifth session)

Two more real gaps the user found by using the app, both in
`goal_detail_sheet.dart`:

1. **Date range was hidden for ongoing goals.** The "runs: start – end"
   stat row only ever rendered `if (progress.goal.isDateBound)` — but most
   goals are *not* date-bound (the default end date is ~1 year out, read as
   "ongoing" per `Goal.isDateBound`/`ongoingGoalSpan`), so for the common
   case the date range was never shown at all, which the user flagged.
   Fixed by always showing a row, labeled differently depending on which
   kind of goal it is: date-bound goals still show `runs: start – end`;
   ongoing goals now show `active since: start` — deliberately *not* a
   full range, since an ongoing goal's own end date is just an
   implementation detail, not a real constraint, and showing it as one
   would misrepresent the goal (this was the actual reasoning the original
   code's now-removed `if` was working around — the fix keeps that intent,
   it just no longer throws away the start date too).
2. **Only today's target was shown, not the full week's breakdown.** The
   "target" stat row read like "3 h 30 this week · today 30 m" — accurate,
   but for a goal like "Walking / varies by day" there was no way to see
   *how* it varies without opening the edit sheet. Added a new
   `_TargetPerDayRow` — a compact 7-day strip (day label + that day's own
   target, or "off") — right under the existing target stat row.

Two new widget tests cover both (`test/widget_test.dart`): one confirming
`active since` (not `runs`) with the real start date for an ongoing goal,
one confirming all 7 day labels and the correct per-day target values
(Walking: 5× "1 h" for Mon–Fri, 2× "2 h 30" for Sat–Sun, per
`mock_goals.dart`). Verified: `flutter analyze` clean, both new tests plus
the full suite pass. Live tap-through wasn't achieved on the simulator this
round either (documented flakiness, see **Known environment quirks**) —
same fallback as before, relying on the widget tests' precise finders.

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
