# Calendar Tracker — session handoff

Written 2026-08-23 to resume this work in a fresh session. Read this first, then
verify anything time-sensitive (git status, test count, Firebase state) since it
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
Git remote: `https://github.com/drivector/calendar.git` (empty remote — see
**Git status** below, nothing has been pushed yet).

## Stack

- Flutter, `flutter_riverpod` for state (StateNotifierProvider for mutable
  collections, derived `Provider`s for computed values — no codegen).
- All data is currently **in-memory mock data** — nothing persists between app
  launches. This is what the in-progress Firebase work (see below) replaces.
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
  seed data. `dummy_data.dart` is meant to be user-editable (empty
  `dummyGoals`/`dummyCategories` templates).

## Testing

`flutter analyze` is clean; `flutter test` currently passes **65 tests**
across `test/models/`, `test/state/`, and `test/widget_test.dart`. Convention
established this session: after any change, run both and fix before moving on.
Run from `app/`:
```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter analyze
flutter test
```

## Git status — ⚠️ nothing has been pushed

- One local commit exists (`a18a953`, "Build Calendar Tracker: ...") but it
  was made **before** most of the Goals/navigation work below and was
  **never pushed** — the remote (`drivector/calendar`) is genuinely empty
  (confirmed via `git ls-remote`/`git fetch`, both return nothing).
- Since that commit, a large amount of uncommitted work has accumulated: the
  entire unified goal-schedule model, goal-block generation, live Week view,
  day/week/tab navigation, and button redesign. `git status` shows ~12
  modified files plus 2 new untracked files
  (`lib/models/goal_planned_blocks.dart`,
  `test/models/goal_planned_blocks_test.dart`).
- **This session never got explicit permission to commit this second batch**
  — only the very first commit was pre-approved. Ask before committing/pushing.
- No git credentials were configured for pushing earlier in this session
  (HTTPS push failed with no stored credential) — that may or may not still
  be true; re-check before assuming a push will work non-interactively.

## In progress: real accounts (Firebase Auth) + Firestore persistence

The user asked for "user management" and, after discussion, chose the
biggest-scope option: real sign-up/login via **Firebase Auth**, plus
**replacing all in-memory mock data with Firestore**, scoped per account
(goals, planned/tracked blocks, categories all become per-user Firestore
collections instead of `StateNotifierProvider`s over local lists).

### Environment setup completed this session
- Node.js was missing entirely; user installed it via the official
  nodejs.org macOS ARM64 `.pkg` installer (now `v24.19.0` at `/usr/local/bin`).
- `npm install -g firebase-tools` failed with `EACCES` (default global prefix
  `/usr/local/lib/node_modules` isn't user-writable). Fixed by pointing npm's
  global prefix at a user directory instead of using `sudo`:
  ```bash
  npm config set prefix "$HOME/.npm-global"
  ```
  `~/.npm-global/bin` and `~/.pub-cache/bin` (for `flutterfire_cli`, installed
  via `dart pub global activate flutterfire_cli`) were both added to PATH in
  `~/.zshrc`. **A brand-new terminal window will have these on PATH
  automatically; a terminal that was already open before this session won't
  — `source ~/.zshrc` or open a new window/tab.**
- `firebase-tools` v15.28.1 and `flutterfire_cli` v1.4.1 are installed and
  confirmed working (`firebase --version`, `flutterfire --version`).
- User is **logged in** to the Firebase CLI (`firebase login` completed
  successfully via the `--no-localhost` device-code flow — there was some
  back-and-forth with duplicate/mismatched login sessions from running the
  command in two different terminals; it resolved once they used one
  consistent terminal for the whole flow).
- User created a Firebase project: **display name "TrackMyDay", project ID
  `trackmyday-6380a`** (confirmed via `firebase projects:list`). Not yet
  confirmed whether Email/Password auth and Firestore have actually been
  enabled in that project's console (the instructions given asked for both,
  but this wasn't independently re-verified after project creation).

### Not yet done — pick up here
1. **Verify** Firestore + Email/Password Auth are enabled on `trackmyday-6380a`
   in the Firebase console (Build → Authentication → Sign-in method; Build →
   Firestore Database).
2. **Run `flutterfire configure`** from `app/` (select the `trackmyday-6380a`
   project, select iOS + macOS platforms). This generates
   `lib/firebase_options.dart` and registers/downloads platform config
   (`GoogleService-Info.plist` etc.) automatically. Neither this file nor
   those configs exist in the repo yet — confirmed via a fresh search before
   writing this handoff.
3. Add `firebase_core`, `firebase_auth`, `cloud_firestore` to `pubspec.yaml`.
4. Initialize Firebase in `main.dart` (`Firebase.initializeApp` before
   `runApp`).
5. Design + build sign-up/login/logout UI in the app's own Modernist system
   (no existing design reference for this, same situation as Categories
   admin earlier — built fresh).
6. Add an auth-gate wrapping `RootShell` (splash/loading while checking auth
   state, redirect to login if signed out).
7. Migrate `goalsProvider`, `allPlannedBlocksProvider`, `allTrackedBlocksProvider`,
   `categoriesProvider` (currently local `StateNotifierProvider`s seeded from
   `data/mock/`) to Firestore-backed repositories scoped under the
   authenticated user's UID. Decide the collection shape (likely
   `users/{uid}/goals`, `users/{uid}/plannedBlocks`, etc.) before writing
   security rules.
8. Write Firestore security rules so a user can only read/write their own
   `users/{uid}/**` subtree; deploy via `firebase deploy --only firestore:rules`.
9. Decide what happens to the existing mock/dummy seed data — likely becomes
   either a one-time seed-on-first-login, or is dropped once real Firestore
   data exists, or stays as a fallback for signed-out/demo mode. Not yet
   decided — ask the user rather than assuming.

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
