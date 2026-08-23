import '../../models/planned_block.dart';
import '../../models/tracked_block.dart';
import 'mock_categories.dart';

/// A fixed illustrative day reproducing the reference screenshot
/// (`screenshots/day-view-3a.png`) — not tied to the session's actual
/// current date.
final mockDay = DateTime(2026, 8, 20);

DateTime _at(int hour, int minute) =>
    DateTime(mockDay.year, mockDay.month, mockDay.day, hour, minute);

/// The day view's active window — matches the reference's 07..~18 range
/// (the last planned/tracked block ends at 17:40).
final mockDayWindowStart = _at(7, 0);
final mockDayWindowEnd = _at(18, 0);

final mockPlannedBlocks = <PlannedBlock>[
  PlannedBlock(
    id: 'plan-walk',
    start: _at(7, 0),
    end: _at(7, 45),
    title: 'Walk 45 m',
    categoryId: walkingCategoryId,
  ),
  PlannedBlock(
    id: 'plan-deep-work',
    start: _at(9, 0),
    end: _at(12, 0),
    title: 'Deep work 3 h',
    categoryId: deepWorkCategoryId,
  ),
  PlannedBlock(
    id: 'plan-lunch',
    start: _at(12, 0),
    end: _at(13, 10),
    title: 'Lunch',
    categoryId: adminCategoryId,
  ),
  PlannedBlock(
    id: 'plan-reviews',
    start: _at(14, 0),
    end: _at(15, 30),
    title: 'Reviews 1 h 30',
    categoryId: meetingsCategoryId,
  ),
  PlannedBlock(
    id: 'plan-admin',
    start: _at(17, 0),
    end: _at(17, 30),
    title: 'Admin 30 m',
    categoryId: adminCategoryId,
  ),
];

final mockTrackedBlocks = <TrackedBlock>[
  TrackedBlock(
    id: 'actual-walk',
    start: _at(7, 0),
    end: _at(7, 48),
    title: 'Walk 48 m',
    categoryId: walkingCategoryId,
    sourceId: 'health',
    plannedBlockId: 'plan-walk',
  ),
  TrackedBlock(
    id: 'actual-deep-work',
    start: _at(9, 0),
    end: _at(10, 45),
    title: 'Deep work 1 h 45',
    categoryId: deepWorkCategoryId,
    sourceId: 'jira',
    plannedBlockId: 'plan-deep-work',
  ),
  TrackedBlock(
    id: 'actual-unplanned-call',
    start: _at(10, 45),
    end: _at(11, 25),
    title: 'Unplanned call 40 m',
    categoryId: meetingsCategoryId,
    sourceId: 'calendar',
  ),
  // Nothing tracked over the 12:00–13:10 Lunch plan block — resolves to a
  // computed untracked gap.
  TrackedBlock(
    id: 'actual-reviews',
    start: _at(14, 0),
    end: _at(16, 5),
    title: 'Reviews + 1:1 2 h 05',
    categoryId: meetingsCategoryId,
    sourceId: 'calendar',
    plannedBlockId: 'plan-reviews',
  ),
  TrackedBlock(
    id: 'actual-admin',
    start: _at(17, 0),
    end: _at(17, 40),
    title: 'Admin 40 m',
    categoryId: adminCategoryId,
    sourceId: 'manual',
    plannedBlockId: 'plan-admin',
  ),
];
