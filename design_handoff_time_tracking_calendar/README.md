# Handoff: Time-tracking calendar app

## Overview
A calendar app that tracks how time was actually spent against how it was planned. It ingests
events and activity from external sources (Google / Outlook / Apple calendars, Apple Health /
Google Fit, work tools such as Jira / GitHub / Slack, and screen-time tools such as RescueTime),
classifies that time into categories, and measures it against weekly goals — both targets
("10 h walking / week") and caps ("max 8 h meetings / week"). Users can also log activity
manually and "claim" untracked gaps.

Platforms: mobile (primary) and desktop/web.

## About the Design Files
The files in this bundle are **design references created in HTML** — wireframe prototypes showing
intended structure, hierarchy, and behavior. They are **not production code to copy**. The task is
to **recreate these designs in the target codebase's existing environment** (React, Vue, SwiftUI,
native, etc.) using its established patterns, component library, and styling approach. If no
codebase exists yet, choose the most appropriate framework and implement the designs there.

The HTML is written as a "design component" — a single file with a top-level `<x-dc>` element and
inline styles. Ignore that wrapper machinery; only the markup structure and visual language matter.

## Fidelity
**Low-fidelity wireframes.** Layout, information hierarchy, and flow are decided; visual polish is
not. Grey blocks stand in for inputs and unclassified content; monospace micro-copy is annotation,
not final UI copy. Implement layout and behavior from these, and take styling from the codebase's
existing design system.

One constraint is decided and should be preserved: the **Modernist** design system (see Design
Tokens) — flat, zero border radius, 2px rules between major sections, flush-left labels, Archivo
type, single red accent — plus the four derived category hues.

## Chosen direction
Four exploration rounds are in the file, newest at top. The chosen direction is:

| Element | Chosen option | Where |
| --- | --- | --- |
| Home screen | Timeline-first day view (option 1c) | turn 2 / `#2b` |
| Color treatment | Tinted fill (15%) + 3px colored left edge (option 2b) | turn 2 / `#2b` |
| Day view | Two lanes: plan left, actual right, shared hour gutter (option 3a) | turn 3 / `#3a` |
| Week view | Desktop: 7 day columns each split plan/actual (4a); Mobile: one row per day, plan bar above actual bar (4b) | turn 4 |
| Log activity | Form with duration, category chips, "counts toward" goal (option 1a, colored in 2a/2b) | turn 2 / `#2a` |
| Desktop shell | Left rail nav + month grid + week "ledger" table (option 1d) | turn 2 / `#2a` |

Options 1a, 1b, 1c, 1d, 2a, 3b are **rejected alternatives** kept for context. Build only the
chosen set unless told otherwise.

---

## Screens / Views

### 1. Day view — plan + actual (mobile) — PRIMARY SCREEN
Reference: option `#3a`, width 320px.

**Purpose.** See what was planned next to what actually happened, and fix discrepancies.

**Layout**, top to bottom:
1. **Header bar** — 2px bottom rule. Left: kicker "Thursday" (9px, 600, uppercase, letter-spacing
   .1em, 50% ink) over title "20 Aug" (14px, 600). Right: segmented control `Day | Plan + actual`,
   1px ink border, active option filled ink with white label, 9px 600 labels, 3px 7px padding.
2. **Legend row** — 1px divider below. Two items, 5px gap between swatch and label: a 14x10 dashed
   outline = "planned 8 h 30"; a 14x10 tinted block with 3px colored left edge = "tracked 7 h 20".
3. **Column header** — 3-column grid `38px 1fr 1fr`, cells "Plan" and "Actual" as 9px uppercase
   captions, 1px left divider per cell, 2px ink rule below.
4. **Time body** — same 3-column grid; rows are proportional to duration:
   `grid-template-rows: 64px 128px 52px 84px 1fr` for hour marks 07 / 09 / 12 / 14 / 17.
   Gutter cells hold the hour as 10px monospace at 50% ink.
   - Plan cells: dashed 1px 50%-ink rectangle, 4px padding, 9px 500 label ("Walk 45 m",
     "Deep work 3 h", "Lunch", "Reviews 1 h 30", "Admin 30 m"). Height encodes planned duration.
   - Actual cells: tinted block, `background: color-mix(in oklch, <category> 15%, #fff)`,
     `border-left: 3px solid <category>`, 4px padding; 9px 500 title plus a monospace sub-line
     naming the source ("health", "jira", "calendar").
   - A cell may hold several stacked actual blocks (3px gap) where the plan was one block:
     09:00 planned "Deep work 3 h" resolves to "Deep work 1 h 45 (jira)" + "Unplanned call 40 m".
   - Untracked gaps: cell background `rgba(0,0,0,.03)`, a dashed rectangle containing
     "1 h 10 untracked".
5. **Drift footer** — 2px top rule, caption "Drift today", then label/value rows:
   "deep work −1 h 15", "meetings +1 h 15" (both 10px monospace, space-between).
6. **Tab bar** — 2px top rule, 4 equal tabs `Day | Week | Goals | + Log`, 8.5px 600 uppercase,
   letter-spacing .06em, 9px 8px padding, 1px right divider, inactive 40% ink, active in the accent.

**Interactions.** Tapping an actual block opens its detail (source, category, which goals it feeds).
Tapping an untracked gap opens the claim sheet (see screen 5). Tapping a plan block with nothing
tracked offers "Confirm" — accept the plan as actual. Horizontal swipe moves day to day. The
segmented control switches between actual-only and plan+actual.

### 2. Week view (desktop)
Reference: option `#4a`, 840px wide, min-height 520px.

Header bar: "Week 34 · 17 – 23 Aug" (14px 600) with "planned 46 h · tracked 41 h 20" alongside in
monospace; segmented `Day | Week | Month` right-aligned. Legend row below: dashed = "plan (P)",
tinted+edge = "actual (A)", 45° hatch = "untracked".

Body: a 38px hour gutter (marks 07 / 09 / 12 / 14 / 17, spaced 56 / 104 / 44 / 76px) beside a
7-column grid, each column separated by a **2px ink rule** (day boundaries read stronger than
anything inside a day). Each day column:
- Header: caption "Mon 17" + drift figure ("−1.0", "+0.5", "—" for a day not yet complete),
  space-between, 1px divider below.
- Body: 2-column grid `16px 1fr` with 3px gap and 4px padding — a **narrow plan lane** of dashed
  rectangles and a **wider actual lane** of tinted+edge blocks. Heights encode duration.
- Today's column carries a `rgba(0,0,0,.02)` background wash.

Footer: 2px top rule, four equal cells divided by 1px rules — "Deep work / plan 20 h · real 18 h",
"Meetings / plan 8 h · real 11 h", "Walking / plan 10 h · real 7.5 h", "Untracked / 6 h 10".

**Interaction.** Clicking a day column opens that day in screen 1.

### 3. Week view (mobile)
Reference: option `#4b`, width 320px.

Header bar "Week 34 / 17 – 23 Aug" + segmented `Day | Week`. Summary strip (2px rule below):
"Tracked" caption over "41 h 20" (24px 600) on the left, "planned 46 h · −4 h 40" monospace right.

Body: one row per day, 9px 0 padding, 1px divider between rows, `background: rgba(0,0,0,.03)` on
today. Each row is: 26px monospace day label · a flex-1 stack of two bars (plan bar 8px tall made
of dashed segments; actual bar 11px tall made of solid category segments, 2px gaps, widths from
flex ratios) · a 32px right-aligned monospace drift figure. Untracked time appears in the actual
bar as a 45° hatch segment.

Footer: 2px top rule, caption "Against goals", three space-between rows —
"deep work 18 / 20 h", "meetings 11 / 8 h — over", "walking 7.5 / 10 h". Then the tab bar.

### 4. Goals
Reference: option `#2b` (second screen), width 284px.

Header "Goals" + segmented `Week | Month`. Body is 12px padding, 16px gap between goals. Each goal
is a block with `border-left: 3px solid <category>` and 10px left padding:
- Title row: name (14px 600) and "7.5 / 10 h" monospace, space-between.
- Progress bar: 14px tall, track `color-mix(in oklch, <category> 15%, #fff)`, fill the solid
  category color at the completion percentage.
- **Pace marker**: a 2px x 20px ink bar absolutely positioned at the expected-by-now percentage
  (left: 82%, top: -3px) — the user is behind if the fill sits left of the marker.
- Status line: monospace, "behind pace" / "on pace" / "over cap by 3 h".

Cap-type goals (Meetings max 8 h, Admin max 4 h) use the same anatomy; a full bar means the cap is
reached or exceeded. Below the list: 2px rule, then a secondary "+ New goal" button (2px ink border,
transparent fill, 10px 600 uppercase label, **flush left**).

Goals in the wireframes: Walking 10 h/wk target; Deep work 20 h/wk target; Meetings max 8 h/wk;
Admin max 4 h/wk; Screen after 21:00 max 3 h/wk.

### 5. Log activity (manual entry)
Reference: option `#2a` (third screen), width 284px.

Header "Log activity" with a "cancel" affordance. Fields, 12px gap:
- "Activity" — text/autocomplete input (34px tall).
- "Start" and "End" — two inputs side by side, 10px gap, flex 1 each.
- "Duration" — computed, displayed large: 30px 600 "1 h 20 m".
- 1px divider.
- "Category" — wrapping chip row. Unselected chip: 1px 30%-ink border, 9px monospace label, with an
  8x8 category color swatch. Selected chip: solid category fill, white label and white swatch.
  Chips: walking, deep work, meeting, admin, "+".
- "Counts toward" — chip showing the goal the entry feeds ("Deep work 20 h/wk"), derived from the
  chosen category; editable.
- "Note" — textarea (52px).

Footer pinned to bottom (2px top rule): primary accent button "Save entry" (full width, label flush
left, 10px 600 uppercase) and a monospace hint "or hold the + tab to start a live timer".

All field labels are 9px 600 uppercase captions above their control.

### 6. Claim untracked time (bottom sheet)
Reference: option `1c` third screen, over the day view.

Sheet rises over a dimmed day view, 2px top rule, white fill. Title row: "Claim 12:00 – 13:10"
(14px 600) with "close". Duration stepper: outlined "–" and "+" buttons flanking a 28px 600
duration. 1px divider. Caption "Category" over a 2-column grid of outlined option buttons
(Walking, Deep work, Meeting, Errands, Admin, Other), 8px gap. Below: a monospace suggestion line
("suggested: Errands — calendar had 'grocery run'"). Primary accent "Save" button at the bottom.

### 7. Desktop shell — month + ledger
Reference: option `#2a` (fourth screen), 720px wide.

Header bar: "August 2026" (14px 600) plus "4 calendars · 3 apps connected" monospace; segmented
`Day | Week | Month` right.

Three columns:
- **Left rail, 132px**, 2px right rule. Nav items 8px 12px, 11px type, each with a 3px transparent
  left border that becomes the accent on the active item (Calendar / Goals / Activities / Sources).
  Below the nav: "Legend" caption and the four category swatches with monospace labels. Pinned to
  the bottom: primary "+ Log" button.
- **Center month grid.** Weekday caption row (Mon–Sun, 9px uppercase) with 1px rule below; then a
  7-column grid, equal auto rows, 1px 12%-ink cell rules, 6px padding. Each cell: day number in
  10px monospace, then up to three 5px-tall category bars whose widths encode hours. Today gets
  `outline: 2px solid ink; outline-offset: -2px`.
- **Right sidebar, 230px**, 2px left rule. "Week 34 ledger" caption header (2px rule below), then a
  table: columns Goal / Plan / Real; header cells 9px uppercase with a 2px bottom rule; rows 8px
  padding with 1px rules; goal names prefixed by an 8x8 category swatch; untracked row uses a
  dashed swatch. Rows: Walking 10 h / 7.5 · Deep work 20 h / 18.0 · Meetings 8 h / 11.0 ·
  Admin 4 h / 3.2 · Untracked — / 6.1. Pinned bottom (2px top rule): "Balance" caption,
  "−2 h 30" at 22px 600, and "against plan, week to date".

### 8. Goals table (desktop)
Reference: option `#2a` (fifth screen), 420px wide.

Header "Goals" with a secondary "+ New" button. Table columns: Goal / Target / 8-week trend / Now.
The trend cell is an 8-bar sparkline, 5px bars, 2px gaps, 20px tall — solid ink for weeks that met
the target, light grey for weeks that missed, the accent for the current week. Bottom panel (2px
top rule) edits the selected goal: caption "Walking — rule", a chip row of its sources
("Apple Health: walking", "cal: 'walk'", "manual", "+ add source"), then "Target" [input] "hours /
week" and "Window" [input] rows.

---

## Not yet designed
These were discussed but never drawn — design them in-app or ask for wireframes:
- Onboarding and the connect-your-apps / source-permission flow (a Sources screen is in the nav).
- Category management (creating categories and their colors).
- Notifications and nudges.
- Settings.
- Activity detail and goal detail on desktop (mobile versions exist as options `1b` screens 2–3).

## Interactions & Behavior
- **Navigation.** Mobile: 4 tabs (Day, Week, Goals, + Log). Desktop: left rail (Calendar, Goals,
  Activities, Sources) with a Day/Week/Month segmented control in the header. Day and week views
  step through time; clicking a day in a week or month view opens the day view.
- **Claiming gaps.** Any interval with no source-attributed activity renders as an untracked gap in
  the day view and a hatched segment in aggregates. Tapping it opens the claim sheet, prefilled with
  the gap's bounds and a suggested category derived from overlapping calendar events.
- **Confirming plans.** A planned block with no tracked counterpart offers "Confirm" — one tap
  writes the plan through as actual.
- **Categorising imports.** Incoming activity is auto-categorised by rule (source + keyword). Where
  a rule is ambiguous the item appears in a review list ("count Strava run toward Walking?") with an
  accept / reassign choice, and the answer should be offered as a new rule.
- **Pace.** Goal progress is judged against elapsed proportion of the week, not just the total — the
  pace marker's position is (elapsed week fraction) x 100%. Status text: on pace / behind pace /
  over cap.
- **Drift.** Per day and per week, drift = tracked minus planned, per category, signed, shown to
  the nearest quarter hour ("−1 h 15", "−1.0" in compact columns).
- **Live timer.** Long-pressing the "+ Log" tab starts a running timer instead of opening the form.
- **States to design in implementation.** Loading (sources syncing), empty (no sources connected, no
  goals yet), error (a source's auth expired), offline. None are wireframed.
- **Responsive.** The day view's two lanes hold down to ~320px; the week view switches from the
  7-column grid (screen 2) to stacked day rows (screen 3) below roughly 700px.
- **Motion.** None specified. Keep transitions short and non-decorative; the design system is flat
  and static by intent.

## State Management
- `selectedDate`, `viewMode` ('day' | 'week' | 'month'), `dayLayer` ('actual' | 'plan+actual').
- `plannedBlocks[]`: id, start, end, title, categoryId, sourceCalendarId.
- `trackedBlocks[]`: id, start, end, title, categoryId, sourceId, confidence, plannedBlockId?.
- `untrackedGaps[]`: derived — the complement of trackedBlocks within the day's active window,
  minimum duration threshold applied.
- `categories[]`: id, name, color.
- `goals[]`: id, name, categoryIds, type ('target' | 'cap'), targetHours, period ('week'),
  window?, sourceRules[].
- `goalProgress`: derived per goal — actualHours, expectedByNowHours (pace), status.
- `drift`: derived per day and per category — trackedHours minus plannedHours.
- `sources[]`: id, kind, displayName, authStatus, lastSyncAt.
- `reviewQueue[]`: ambiguous imports awaiting categorisation.
- `draftLogEntry`: the manual-entry form's working state; `runningTimer`.
- Data fetching: periodic sync per source, incremental since `lastSyncAt`; classification runs on
  ingest; goal progress recomputes on any tracked-block change.

## Design Tokens
From the bound **Modernist** design system (`_ds/modernist-.../styles.css`) — use its variables, not
these literals, wherever the codebase can:
- `--color-bg` #f3f2f2 · `--color-surface` #eae9e9 · `--color-text` #201e1d
- `--color-accent` #ec3013 · `--color-accent-600` #dd2b0f (pressed) · `--color-accent-700` #ae1800
  (small accent text — the accent itself is only cleared for large text and chrome)
- `--color-divider` = ink at 40%
- Neutral ramp 100–900: #f8f4f4 #eae7e7 #d7d3d3 #bab6b6 #9b9797 #7d7979 #605d5d #444141 #2d2b2b
- `--font-heading` / `--font-body`: "Archivo", system-ui, sans-serif (heading weight 800)
- `--radius-*`: **0 everywhere. Do not round a corner.**
- Spacing scale `--space-1` = 4px, in 4px steps.
- Rules: 2px solid ink between major sections; 1px `--color-divider` or ink at 8–15% inside a
  section. Do not soften the 2px rules.
- Buttons: primary = solid accent fill, white label; secondary = 2px ink border, transparent fill.
  **Labels are flush left, never centered**, even when the button is wider than its label.

**Category colors** (an extension, not in the design system — derived in OKLCH at the accent's own
lightness and chroma so red reads as one category among four rather than a second accent):
- Walking `oklch(0.58 0.19 145)`
- Deep work `oklch(0.58 0.19 255)`
- Meetings `var(--color-accent)` (#ec3013) — pinned to the theme accent
- Admin `oklch(0.58 0.19 300)`
- Untracked: no color — a 1px dashed 50%-ink outline in the day view, a 45° hatch
  (`repeating-linear-gradient(45deg, rgba(0,0,0,.14) 0 3px, transparent 3px 6px)`) in aggregates.
- Block fill = `color-mix(in oklch, <category> 15%, #fff)` with `border-left: 3px solid <category>`.
- Any new category must be a fifth hue at the same 0.58 lightness / 0.19 chroma.

**Wireframe-only values** (do not ship): grey placeholder blocks `rgba(0,0,0,.1)`; monospace
annotation text at 10px / 50% ink; the 9px caption size — real UI type should follow the codebase's
scale, minimum 11px for labels and 44px minimum touch targets on mobile.

## Assets
None. No images, photographs, or custom illustration. Icons: use **Lucide** (https://lucide.dev),
per the design system. The wireframes use no icons — add them sparingly where a label alone is
ambiguous (source badges, nav rail).

## Screenshots
`screenshots/` holds a render of each chosen option:
- `day-view-3a.png` — day view, plan + actual lanes (screen 1)
- `week-desktop-4a.png` — desktop week (screen 2)
- `week-mobile-4b.png` — mobile week (screen 3)
- `home-goals-2b.png` — timeline home + goals, tinted treatment (screens 4, and the home the day view sits in)
- `log-and-desktop-2a.png` — log activity, desktop month + ledger, goals table (screens 5, 7, 8)

## Files
- `Calendar Tracker Wireframes.dc.html` — all four exploration rounds, newest turn at the top.
  Turn 4 = week views (`#4a`, `#4b`); turn 3 = day views (`#3a` chosen, `#3b` rejected);
  turn 2 = home / goals / log / desktop with color (`#2b` chosen for treatment, `#2a` holds the
  desktop and log screens); turn 1 = the four original navigation directions.
  Option ids are visible badges in the file — `#3a` scrolls to that option.
- `support.js` — runtime for the HTML wrapper. Not part of the design; ignore.
- `_ds/modernist-69ad9f4a-c3c3-4ff9-8f3d-0b0e08aedbd5/` — the Modernist design system:
  `styles.css` (token sheet + component classes) and `readme.md` (its usage guide). Port the tokens
  into the target codebase rather than linking this stylesheet.
