import '../../models/category.dart';
import '../../models/goal.dart';
import '../../models/planned_block.dart';
import '../../models/tracked_block.dart';
import 'mock_categories.dart';

/// Edit this file to change what the app launches with.
///
/// Everything here is additive — it loads on top of the built-in 20 Aug
/// mock day (`mock_day_20aug.dart`), the 5 built-in goals, and the 5
/// built-in categories, rather than replacing them. Nothing else in the app
/// needs to change: `dummyPlannedBlocks`/`dummyTrackedBlocks` are picked up
/// by the Day view (and, through it, Week and Goals) for whatever dates you
/// give them; `dummyGoals`/`dummyCategories` just extend those lists.
///
/// The starter data below fills in the rest of the week around the built-in
/// Thursday (17–19 and 21–23 Aug 2026) so the Week view and day-to-day swipe
/// have something real to show on every day, not just the one. Replace or
/// add to any of the four lists freely — ids just need to be unique within
/// their own list.

DateTime _at(int year, int month, int day, int hour, [int minute = 0]) =>
    DateTime(year, month, day, hour, minute);

final dummyPlannedBlocks = <PlannedBlock>[
  // Monday 17 Aug
  PlannedBlock(
    id: 'dummy-plan-mon-walk',
    start: _at(2026, 8, 17, 7, 30),
    end: _at(2026, 8, 17, 8, 0),
    title: 'Walk 30 m',
    categoryId: walkingCategoryId,
  ),
  PlannedBlock(
    id: 'dummy-plan-mon-deep-work',
    start: _at(2026, 8, 17, 9, 0),
    end: _at(2026, 8, 17, 12, 0),
    title: 'Deep work 3 h',
    categoryId: deepWorkCategoryId,
  ),
  PlannedBlock(
    id: 'dummy-plan-mon-admin',
    start: _at(2026, 8, 17, 16, 0),
    end: _at(2026, 8, 17, 16, 30),
    title: 'Admin 30 m',
    categoryId: adminCategoryId,
  ),

  // Tuesday 18 Aug
  PlannedBlock(
    id: 'dummy-plan-tue-walk',
    start: _at(2026, 8, 18, 7, 0),
    end: _at(2026, 8, 18, 7, 30),
    title: 'Walk 30 m',
    categoryId: walkingCategoryId,
  ),
  PlannedBlock(
    id: 'dummy-plan-tue-deep-work',
    start: _at(2026, 8, 18, 9, 0),
    end: _at(2026, 8, 18, 12, 30),
    title: 'Deep work 3 h 30',
    categoryId: deepWorkCategoryId,
  ),
  PlannedBlock(
    id: 'dummy-plan-tue-meeting',
    start: _at(2026, 8, 18, 14, 0),
    end: _at(2026, 8, 18, 15, 0),
    title: 'Client call',
    categoryId: meetingsCategoryId,
  ),

  // Wednesday 19 Aug
  PlannedBlock(
    id: 'dummy-plan-wed-walk',
    start: _at(2026, 8, 19, 7, 30),
    end: _at(2026, 8, 19, 8, 0),
    title: 'Walk 30 m',
    categoryId: walkingCategoryId,
  ),
  PlannedBlock(
    id: 'dummy-plan-wed-deep-work',
    start: _at(2026, 8, 19, 9, 0),
    end: _at(2026, 8, 19, 11, 30),
    title: 'Deep work 2 h 30',
    categoryId: deepWorkCategoryId,
  ),
  PlannedBlock(
    id: 'dummy-plan-wed-admin',
    start: _at(2026, 8, 19, 15, 0),
    end: _at(2026, 8, 19, 15, 30),
    title: 'Admin 30 m',
    categoryId: adminCategoryId,
  ),

  // Friday 21 Aug
  PlannedBlock(
    id: 'dummy-plan-fri-walk',
    start: _at(2026, 8, 21, 7, 0),
    end: _at(2026, 8, 21, 7, 30),
    title: 'Walk 30 m',
    categoryId: walkingCategoryId,
  ),
  PlannedBlock(
    id: 'dummy-plan-fri-deep-work',
    start: _at(2026, 8, 21, 9, 0),
    end: _at(2026, 8, 21, 12, 0),
    title: 'Deep work 3 h',
    categoryId: deepWorkCategoryId,
  ),
  PlannedBlock(
    id: 'dummy-plan-fri-meeting',
    start: _at(2026, 8, 21, 13, 0),
    end: _at(2026, 8, 21, 14, 0),
    title: 'Sprint retro',
    categoryId: meetingsCategoryId,
  ),

  // Saturday 22 Aug — weekend, lighter plan
  PlannedBlock(
    id: 'dummy-plan-sat-walk',
    start: _at(2026, 8, 22, 9, 0),
    end: _at(2026, 8, 22, 10, 30),
    title: 'Long walk',
    categoryId: walkingCategoryId,
  ),

  // Sunday 23 Aug
  PlannedBlock(
    id: 'dummy-plan-sun-walk',
    start: _at(2026, 8, 23, 10, 0),
    end: _at(2026, 8, 23, 11, 30),
    title: 'Long walk',
    categoryId: walkingCategoryId,
  ),
];

final dummyTrackedBlocks = <TrackedBlock>[
  // Monday 17 Aug
  TrackedBlock(
    id: 'dummy-actual-mon-walk',
    start: _at(2026, 8, 17, 7, 30),
    end: _at(2026, 8, 17, 7, 55),
    title: 'Walk 25 m',
    categoryId: walkingCategoryId,
    sourceId: 'health',
    plannedBlockId: 'dummy-plan-mon-walk',
  ),
  TrackedBlock(
    id: 'dummy-actual-mon-deep-work',
    start: _at(2026, 8, 17, 9, 10),
    end: _at(2026, 8, 17, 11, 0),
    title: 'Deep work 1 h 50',
    categoryId: deepWorkCategoryId,
    sourceId: 'jira',
    plannedBlockId: 'dummy-plan-mon-deep-work',
  ),
  TrackedBlock(
    id: 'dummy-actual-mon-sync',
    start: _at(2026, 8, 17, 11, 0),
    end: _at(2026, 8, 17, 11, 30),
    title: 'Team sync',
    categoryId: meetingsCategoryId,
    sourceId: 'calendar',
  ),
  TrackedBlock(
    id: 'dummy-actual-mon-admin',
    start: _at(2026, 8, 17, 16, 0),
    end: _at(2026, 8, 17, 16, 20),
    title: 'Admin 20 m',
    categoryId: adminCategoryId,
    sourceId: 'manual',
    plannedBlockId: 'dummy-plan-mon-admin',
  ),

  // Tuesday 18 Aug
  TrackedBlock(
    id: 'dummy-actual-tue-walk',
    start: _at(2026, 8, 18, 7, 0),
    end: _at(2026, 8, 18, 7, 35),
    title: 'Walk 35 m',
    categoryId: walkingCategoryId,
    sourceId: 'health',
    plannedBlockId: 'dummy-plan-tue-walk',
  ),
  TrackedBlock(
    id: 'dummy-actual-tue-deep-work',
    start: _at(2026, 8, 18, 9, 15),
    end: _at(2026, 8, 18, 11, 45),
    title: 'Deep work 2 h 30',
    categoryId: deepWorkCategoryId,
    sourceId: 'jira',
    plannedBlockId: 'dummy-plan-tue-deep-work',
  ),
  TrackedBlock(
    id: 'dummy-actual-tue-meeting',
    start: _at(2026, 8, 18, 14, 0),
    end: _at(2026, 8, 18, 15, 10),
    title: 'Client call',
    categoryId: meetingsCategoryId,
    sourceId: 'calendar',
    plannedBlockId: 'dummy-plan-tue-meeting',
  ),

  // Wednesday 19 Aug
  TrackedBlock(
    id: 'dummy-actual-wed-walk',
    start: _at(2026, 8, 19, 7, 30),
    end: _at(2026, 8, 19, 7, 50),
    title: 'Walk 20 m',
    categoryId: walkingCategoryId,
    sourceId: 'health',
    plannedBlockId: 'dummy-plan-wed-walk',
  ),
  TrackedBlock(
    id: 'dummy-actual-wed-deep-work',
    start: _at(2026, 8, 19, 9, 0),
    end: _at(2026, 8, 19, 10, 30),
    title: 'Deep work 1 h 30',
    categoryId: deepWorkCategoryId,
    sourceId: 'github',
    plannedBlockId: 'dummy-plan-wed-deep-work',
  ),
  TrackedBlock(
    id: 'dummy-actual-wed-admin',
    start: _at(2026, 8, 19, 15, 0),
    end: _at(2026, 8, 19, 15, 45),
    title: 'Admin 45 m',
    categoryId: adminCategoryId,
    sourceId: 'manual',
    plannedBlockId: 'dummy-plan-wed-admin',
  ),

  // Friday 21 Aug
  TrackedBlock(
    id: 'dummy-actual-fri-walk',
    start: _at(2026, 8, 21, 7, 0),
    end: _at(2026, 8, 21, 7, 20),
    title: 'Walk 20 m',
    categoryId: walkingCategoryId,
    sourceId: 'health',
    plannedBlockId: 'dummy-plan-fri-walk',
  ),
  TrackedBlock(
    id: 'dummy-actual-fri-deep-work',
    start: _at(2026, 8, 21, 9, 30),
    end: _at(2026, 8, 21, 11, 0),
    title: 'Deep work 1 h 30',
    categoryId: deepWorkCategoryId,
    sourceId: 'jira',
    plannedBlockId: 'dummy-plan-fri-deep-work',
  ),
  TrackedBlock(
    id: 'dummy-actual-fri-retro',
    start: _at(2026, 8, 21, 13, 0),
    end: _at(2026, 8, 21, 14, 15),
    title: 'Sprint retro',
    categoryId: meetingsCategoryId,
    sourceId: 'calendar',
    plannedBlockId: 'dummy-plan-fri-meeting',
  ),

  // Saturday 22 Aug
  TrackedBlock(
    id: 'dummy-actual-sat-walk',
    start: _at(2026, 8, 22, 9, 0),
    end: _at(2026, 8, 22, 10, 15),
    title: 'Long walk',
    categoryId: walkingCategoryId,
    sourceId: 'health',
    plannedBlockId: 'dummy-plan-sat-walk',
  ),
  TrackedBlock(
    id: 'dummy-actual-sat-admin',
    start: _at(2026, 8, 22, 12, 0),
    end: _at(2026, 8, 22, 12, 30),
    title: 'Errands',
    categoryId: adminCategoryId,
    sourceId: 'manual',
  ),
  TrackedBlock(
    id: 'dummy-actual-sat-screen',
    start: _at(2026, 8, 22, 21, 30),
    end: _at(2026, 8, 22, 22, 30),
    title: 'Screen time 1 h',
    categoryId: screenTimeCategoryId,
    sourceId: 'device',
  ),

  // Sunday 23 Aug
  TrackedBlock(
    id: 'dummy-actual-sun-walk',
    start: _at(2026, 8, 23, 10, 0),
    end: _at(2026, 8, 23, 11, 20),
    title: 'Long walk',
    categoryId: walkingCategoryId,
    sourceId: 'health',
    plannedBlockId: 'dummy-plan-sun-walk',
  ),
  TrackedBlock(
    id: 'dummy-actual-sun-screen',
    start: _at(2026, 8, 23, 21, 15),
    end: _at(2026, 8, 23, 22, 0),
    title: 'Screen time 45 m',
    categoryId: screenTimeCategoryId,
    sourceId: 'device',
  ),
];

/// Extra goals appended to the 5 built-in ones — empty by default, add your
/// own the same way `mock_goals.dart` defines its 5 (see `Goal` for fields).
final dummyGoals = <Goal>[];

/// Extra categories appended to the 5 built-in ones — empty by default, add
/// your own the same way `mock_categories.dart` defines its 5. Use a color
/// from `categoryColorPalette` (in `state/categories_providers.dart`) to
/// stay visually consistent with the existing ones.
final dummyCategories = <Category>[];
