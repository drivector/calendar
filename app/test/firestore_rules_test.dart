import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/data/firestore/firestore_list_repository.dart';
import 'package:calendar_tracker/data/mock/dummy_data.dart';
import 'package:calendar_tracker/data/mock/mock_categories.dart';
import 'package:calendar_tracker/data/mock/mock_day_20aug.dart';
import 'package:calendar_tracker/data/mock/mock_goals.dart';
import 'package:calendar_tracker/data/onboarding_categories.dart';
import 'package:calendar_tracker/models/category.dart';
import 'package:calendar_tracker/models/clock_time.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/planned_block.dart';
import 'package:calendar_tracker/models/running_activity.dart';
import 'package:calendar_tracker/models/tracked_block.dart';
import 'package:calendar_tracker/models/user_settings.dart';

import 'support/firestore_rules.dart';

/// The rules half of "does a write the app makes actually land". Every
/// other test in this suite runs against `FakeFirebaseFirestore`, which
/// accepts any document at all — so a document shape the deployed rules
/// reject looks identical to a successful save, right up until a real
/// account tries it. That's exactly how the categoryId/goalId mismatch
/// shipped: `PlannedBlock`/`TrackedBlock` stopped writing `categoryId`,
/// the rules kept demanding it, and every new activity was silently
/// permission-denied while all 236 tests stayed green.
void main() {
  final rules = FirestoreRules.fromFile();

  group('firestore.rules parsing', () {
    test('every per-user collection in the rules file is parsed', () {
      expect(
        rules.collections.keys,
        containsAll([
          'categories',
          'goals',
          'plannedBlocks',
          'trackedBlocks',
          'settings',
          'state',
        ]),
      );
    });

    test('no write condition goes unchecked', () {
      // A rule clause this parser doesn't understand would otherwise make
      // the contract below quietly weaker than the deployed rules.
      expect(rules.unparsedConditions, isEmpty);
    });

    test('the collections that validate their documents really do', () {
      // Guards against the checks below passing vacuously — e.g. a regex
      // that silently stops matching after the rules file is reformatted
      // would leave every requiredKeys set empty and every document
      // trivially "valid".
      for (final name in [
        'categories',
        'goals',
        'plannedBlocks',
        'trackedBlocks',
      ]) {
        expect(
          rules.collections[name]!.requiredKeys,
          isNotEmpty,
          reason: '$name should require fields',
        );
      }
      expect(
        rules.collections['plannedBlocks']!.requiredKeys,
        containsAll(['start', 'end', 'title', 'goalId']),
      );
      expect(
        rules.collections['trackedBlocks']!.requiredKeys,
        containsAll(['start', 'end', 'title', 'goalId', 'sourceId']),
      );
      expect(rules.maxStringLength, greaterThan(0));
    });

    test('every per-user collection is gated on the owner check', () {
      for (final rule in rules.collections.values) {
        expect(
          rule.ownerGated,
          isTrue,
          reason:
              '${rule.collection} allows a method without isOwner(uid): '
              '${rule.conditionsByMethod}',
        );
      }
    });

    test(
      'the checker rejects the exact document shape that shipped broken',
      () {
        // The real regression, reconstructed: rules still demanding
        // categoryId, against the goalId-only block the app writes today.
        final staleRules = FirestoreRules.parse('''
service cloud.firestore {
  match /databases/{database}/documents {
    function isOwner(uid) { return request.auth.uid == uid; }
    function isReasonableString(value) {
      return value is string && value.size() <= 500;
    }
    match /users/{uid}/plannedBlocks/{docId} {
      allow read: if isOwner(uid);
      allow create, update: if isOwner(uid)
          && request.resource.data.keys().hasAll(['start', 'end', 'title', 'categoryId'])
          && isReasonableString(request.resource.data.categoryId);
      allow delete: if isOwner(uid);
    }
  }
}''');
        final block = PlannedBlock(
          id: 'plan-1',
          start: DateTime(2026, 8, 20, 9),
          end: DateTime(2026, 8, 20, 10),
          title: 'Deep work',
          goalId: 'goal-1',
        );
        expect(
          staleRules.violations('plannedBlocks', block.toMap()),
          contains(contains("'categoryId' is missing")),
        );
        // ...and passes against the rules the project actually deploys, so
        // this test fails for the right reason if the two drift again.
        expect(rules.violations('plannedBlocks', block.toMap()), isEmpty);
      },
    );

    test('a collection with no rule at all is a violation', () {
      // An unmatched path denies every request — the live-activity
      // `state/runningActivity` doc shipped that way once, so a newly
      // added collection must not read as "unconstrained, therefore fine".
      expect(
        rules.violations('somethingNew', const {'a': 1}),
        contains(contains('no rule matches')),
      );
    });
  });

  group('documents the app writes satisfy the deployed rules', () {
    test('PlannedBlock, including a goal-linked one with no calendar id', () {
      expect(
        rules.violations(
          'plannedBlocks',
          PlannedBlock(
            id: 'plan-1',
            start: DateTime(2026, 8, 20, 9),
            end: DateTime(2026, 8, 20, 10),
            title: 'Deep work',
            goalId: 'goal-1',
          ).toMap(),
        ),
        isEmpty,
      );
      expect(
        rules.violations(
          'plannedBlocks',
          PlannedBlock(
            id: 'plan-2',
            start: DateTime(2026, 8, 20, 9),
            end: DateTime(2026, 8, 20, 10),
            title: 'Imported',
            goalId: 'goal-1',
            sourceCalendarId: 'cal-1',
          ).toMap(),
        ),
        isEmpty,
      );
    });

    test('TrackedBlock, manual and live-activity forms', () {
      expect(
        rules.violations(
          'trackedBlocks',
          TrackedBlock(
            id: 'manual-1',
            start: DateTime(2026, 8, 20, 9),
            end: DateTime(2026, 8, 20, 10),
            title: 'Deep work',
            goalId: 'goal-1',
            sourceId: 'manual',
            note: 'A note',
            plannedBlockId: 'plan-1',
          ).toMap(),
        ),
        isEmpty,
      );
      expect(
        rules.violations(
          'trackedBlocks',
          TrackedBlock(
            id: 'live-1',
            start: DateTime(2026, 8, 20, 9),
            end: DateTime(2026, 8, 20, 10),
            title: 'Walk',
            goalId: 'goal-1',
            sourceId: 'manual',
            status: TrackedBlockStatus.deleted,
          ).toMap(),
        ),
        isEmpty,
      );
    });

    test('Goal, in every schedule mode and lifecycle status', () {
      final weekly = Goal(
        id: 'goal-1',
        name: 'Walk',
        categoryId: 'health',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        scheduleByWeekday: {
          for (var weekday = 1; weekday <= 7; weekday++)
            weekday: [const DayScheduleEntry.duration(Duration(minutes: 45))],
        },
      );
      expect(rules.violations('goals', weekly.toMap()), isEmpty);

      final byDate = Goal(
        id: 'goal-2',
        name: 'Course',
        categoryId: 'learning',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
        scheduleByWeekday: const {},
        scheduleMode: GoalScheduleMode.byDate,
        scheduleByDate: {
          DateTime(2026, 3, 2): [
            DayScheduleEntry.timeRange(
              const ClockRange(ClockTime(9, 0), ClockTime(10, 30)),
            ),
          ],
        },
        reminderMinutesBefore: 15,
        status: GoalLifecycleStatus.deactivated,
      );
      expect(rules.violations('goals', byDate.toMap()), isEmpty);
    });

    test('Category, including every one onboarding offers', () {
      expect(
        rules.violations(
          'categories',
          const Category(
            id: 'health',
            name: 'Health',
            color: Color(0xFF0F6CBD),
          ).toMap(),
        ),
        isEmpty,
      );
      for (final category in onboardingCategories) {
        expect(
          rules.violations('categories', category.toMap()),
          isEmpty,
          reason: 'onboarding category ${category.id}',
        );
      }
    });

    test('RunningActivity and UserSettings singleton docs', () {
      expect(
        rules.violations(
          'state',
          RunningActivity(
            startedAt: DateTime(2026, 8, 20, 9),
            goalId: 'goal-1',
            title: 'Walk',
          ).toMap(),
        ),
        isEmpty,
      );
      expect(
        rules.violations('settings', const UserSettings().toMap()),
        isEmpty,
      );
      expect(
        rules.violations(
          'settings',
          const UserSettings(defaultOpenHour: 7)
              .copyWithWeekday(1, const [
                ClockRange(ClockTime(6, 0), ClockTime(9, 0)),
              ])
              .toMap(),
        ),
        isEmpty,
      );
    });

    test("the app's own input cap is the one the rules enforce", () {
      // The title/name fields limit themselves to kMaxFieldLength so a
      // pasted essay can't produce a write that only the server can
      // reject. That's only true while the two numbers agree.
      expect(kMaxFieldLength, rules.maxStringLength);
    });

    test('a title longer than the rules allow is a violation', () {
      // The other side of the cap above: if a document ever does get
      // built with an over-length string (a code path that skips the
      // input fields, say), this is what production would do with it.
      final tooLong = PlannedBlock(
        id: 'plan-long',
        start: DateTime(2026, 8, 20, 9),
        end: DateTime(2026, 8, 20, 10),
        title: 'x' * (rules.maxStringLength + 1),
        goalId: 'goal-1',
      );
      expect(
        rules.violations('plannedBlocks', tooLong.toMap()),
        contains(contains('over')),
      );
    });

    test('every seeded fixture document, as written by its own model', () {
      for (final category in [...mockCategories, ...dummyCategories]) {
        expect(
          rules.violations('categories', category.toMap()),
          isEmpty,
          reason: category.id,
        );
      }
      for (final goal in [...mockGoals, ...dummyGoals]) {
        expect(rules.violations('goals', goal.toMap()), isEmpty, reason: goal.id);
      }
      for (final block in [...mockPlannedBlocks, ...dummyPlannedBlocks]) {
        expect(
          rules.violations('plannedBlocks', block.toMap()),
          isEmpty,
          reason: block.id,
        );
      }
      for (final block in [...mockTrackedBlocks, ...dummyTrackedBlocks]) {
        expect(
          rules.violations('trackedBlocks', block.toMap()),
          isEmpty,
          reason: block.id,
        );
      }
    });
  });

  group('a written document reads back as the object that wrote it', () {
    // The other end of the same contract: a rules-valid document is no use
    // if `fromMap` can't reconstruct it. Every field below is one Firestore
    // actually stores, so a rename on either side surfaces here.
    test('PlannedBlock', () {
      final block = PlannedBlock(
        id: 'plan-1',
        start: DateTime(2026, 8, 20, 9),
        end: DateTime(2026, 8, 20, 10, 30),
        title: 'Deep work',
        goalId: 'goal-1',
        sourceCalendarId: 'cal-1',
      );
      final restored = PlannedBlock.fromMap(block.id, block.toMap());
      expect(restored.start, block.start);
      expect(restored.end, block.end);
      expect(restored.title, block.title);
      expect(restored.goalId, block.goalId);
      expect(restored.sourceCalendarId, block.sourceCalendarId);
      // Never persisted — a block read back from Firestore is always a real
      // document, not a synthesized goal-generated one.
      expect(restored.isGoalGenerated, isFalse);
    });

    test('TrackedBlock', () {
      final block = TrackedBlock(
        id: 'manual-1',
        start: DateTime(2026, 8, 20, 9),
        end: DateTime(2026, 8, 20, 10),
        title: 'Deep work',
        goalId: 'goal-1',
        sourceId: 'manual',
        confidence: 0.5,
        plannedBlockId: 'plan-1',
        note: 'A note',
        status: TrackedBlockStatus.deleted,
      );
      final restored = TrackedBlock.fromMap(block.id, block.toMap());
      expect(restored.start, block.start);
      expect(restored.end, block.end);
      expect(restored.title, block.title);
      expect(restored.goalId, block.goalId);
      expect(restored.sourceId, block.sourceId);
      expect(restored.confidence, block.confidence);
      expect(restored.plannedBlockId, block.plannedBlockId);
      expect(restored.note, block.note);
      expect(restored.status, block.status);
    });

    test('Category', () {
      const category = Category(
        id: 'health',
        name: 'Health',
        color: Color(0xFF0F6CBD),
      );
      final restored = Category.fromMap(category.id, category.toMap());
      expect(restored.name, category.name);
      expect(restored.color, category.color);
    });

    test('RunningActivity', () {
      final running = RunningActivity(
        startedAt: DateTime(2026, 8, 20, 9, 15),
        goalId: 'goal-1',
        title: 'Walk',
      );
      final restored = RunningActivity.fromMap(running.toMap());
      expect(restored.startedAt, running.startedAt);
      expect(restored.goalId, running.goalId);
      expect(restored.title, running.title);
    });

    test('UserSettings', () {
      const settings = UserSettings(
        trackingWindowsByWeekday: {
          1: [ClockRange(ClockTime(6, 0), ClockTime(9, 0))],
          3: [
            ClockRange(ClockTime(7, 30), ClockTime(12, 0)),
            ClockRange(ClockTime(17, 0), ClockTime(22, 0)),
          ],
        },
        defaultOpenHour: 7,
      );
      final restored = UserSettings.fromMap(settings.toMap());
      expect(restored.defaultOpenHour, 7);
      // ClockRange carries no `==`, so compare the minutes each range
      // actually round-tripped through Firestore.
      expect(_minutes(restored.windowsForWeekday(1)), [
        (360, 540),
      ]);
      expect(_minutes(restored.windowsForWeekday(3)), [
        (450, 720),
        (1020, 1320),
      ]);
      // A weekday that was never set still falls back to the full day.
      expect(_minutes(restored.windowsForWeekday(2)), [(0, 1440)]);
    });
  });
}

List<(int, int)> _minutes(List<ClockRange> ranges) => [
  for (final range in ranges)
    (range.start.minutesSinceMidnight, range.end.minutesSinceMidnight),
];
