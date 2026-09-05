import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:calendar_tracker/models/clock_time.dart';
import 'package:calendar_tracker/models/goal.dart';
import 'package:calendar_tracker/models/goal_reminders.dart';
import 'package:calendar_tracker/services/goal_reminder_service.dart';

/// [GoalReminderService] had no tests at all: `computeReminderOccurrences`
/// (what *should* be scheduled) was well covered, but nothing checked that
/// the service actually hands those occurrences to the notifications
/// plugin — so "the reminder never fired" was unfalsifiable from the suite.
///
/// The plugin is a singleton with a private constructor, so it can't be
/// subclassed; [_RecordingPlugin] implements the interface instead and
/// records the calls the service makes.
void main() {
  Goal remindableGoal({
    String id = 'goal-work',
    int? reminderMinutesBefore = 15,
  }) => Goal(
    id: id,
    name: 'Work',
    categoryId: 'work',
    startDate: DateTime(2020, 1, 1),
    endDate: DateTime(2099, 12, 31),
    reminderMinutesBefore: reminderMinutesBefore,
    scheduleByWeekday: {
      // Every weekday, so the rolling 14-day window always contains
      // occurrences regardless of what day the suite runs on.
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: [
          const DayScheduleEntry.timeRange(
            ClockRange(ClockTime(9, 0), ClockTime(18, 0)),
          ),
        ],
    },
  );

  test('init points the timezone database at the device\'s own offset', () async {
    final plugin = _RecordingPlugin();
    await GoalReminderService(plugin: plugin).init();

    expect(plugin.initialized, isTrue);
    // The service picks a location by matching UTC offsets rather than
    // asking the platform for a zone name (it has no plugin for that), so
    // what matters is that scheduling lands on the right wall clock.
    expect(
      tz.TZDateTime.from(DateTime(2026, 8, 20, 9), tz.local).hour,
      DateTime(2026, 8, 20, 9).hour,
    );
  });

  test('resync schedules one notification per computed occurrence', () async {
    final plugin = _RecordingPlugin();
    final service = GoalReminderService(plugin: plugin);
    await service.init();

    final goals = [remindableGoal()];
    await service.resync(goals);

    // Recomputed rather than hardcoded: the window is relative to now, so
    // the count depends on the day the suite runs.
    final expected = computeReminderOccurrences(
      goals: goals,
      now: DateTime.now(),
    );
    expect(expected, isNotEmpty, reason: 'fixture should produce reminders');
    expect(plugin.scheduled, hasLength(expected.length));
    expect(
      plugin.scheduled.map((s) => s.id).toSet(),
      expected.map((o) => o.id).toSet(),
    );
    expect(
      plugin.scheduled.map((s) => s.title).toSet(),
      expected.map((o) => o.title).toSet(),
    );
  });

  test('resync clears the old schedule before writing the new one', () async {
    final plugin = _RecordingPlugin();
    final service = GoalReminderService(plugin: plugin);
    await service.init();

    await service.resync([remindableGoal()]);

    expect(plugin.cancelAllCalls, 1);
    // Order matters: cancelling after scheduling would wipe the very
    // reminders just written.
    expect(plugin.log.first, 'cancelAll');
    expect(plugin.log.skip(1), everyElement('schedule'));
  });

  test('a second resync replaces the schedule rather than doubling it', () async {
    final plugin = _RecordingPlugin();
    final service = GoalReminderService(plugin: plugin);
    await service.init();

    final goals = [remindableGoal()];
    await service.resync(goals);
    final first = plugin.scheduled.map((s) => s.id).toList();
    plugin.scheduled.clear();
    await service.resync(goals);

    expect(plugin.cancelAllCalls, 2);
    expect(plugin.scheduled.map((s) => s.id).toList(), first);
  });

  test('a goal with no reminder set schedules nothing at all', () async {
    final plugin = _RecordingPlugin();
    final service = GoalReminderService(plugin: plugin);
    await service.init();

    await service.resync([remindableGoal(reminderMinutesBefore: null)]);

    // Still cancels: a goal whose reminder was just switched off has to
    // lose the notifications already scheduled for it.
    expect(plugin.cancelAllCalls, 1);
    expect(plugin.scheduled, isEmpty);
  });

  test('every reminder is scheduled ahead of now, at its own wall clock',
      () async {
    final plugin = _RecordingPlugin();
    final service = GoalReminderService(plugin: plugin);
    await service.init();

    final goals = [remindableGoal()];
    await service.resync(goals);
    final expectedById = {
      for (final occurrence in computeReminderOccurrences(
        goals: goals,
        now: DateTime.now(),
      ))
        occurrence.id: occurrence,
    };

    for (final scheduled in plugin.scheduled) {
      expect(scheduled.when.isAfter(tz.TZDateTime.now(tz.local)), isTrue);
      final occurrence = expectedById[scheduled.id]!;
      // 15 minutes before a 09:00 start is 08:45 on the device's own
      // clock — a timezone conversion that shifted the hour would still
      // "schedule something", just at the wrong time of day.
      expect(scheduled.when.hour, occurrence.scheduledTime.hour);
      expect(scheduled.when.minute, occurrence.scheduledTime.minute);
      expect(scheduled.when.day, occurrence.scheduledTime.day);
    }
  });
}

class _ScheduledNotification {
  _ScheduledNotification(this.id, this.title, this.body, this.when);

  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime when;
}

/// Records what the service asks the plugin to do. `implements` rather
/// than `extends`: [FlutterLocalNotificationsPlugin]'s only generative
/// constructor is private, so it can't be subclassed from here. The
/// `noSuchMethod` fallback covers the rest of the plugin's surface, none
/// of which this service touches.
class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  final List<_ScheduledNotification> scheduled = [];
  final List<String> log = [];
  int cancelAllCalls = 0;
  bool initialized = false;

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initialized = true;
    return true;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    log.add('cancelAll');
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation
    uiLocalNotificationDateInterpretation,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled.add(_ScheduledNotification(id, title, body, scheduledDate));
    log.add('schedule');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
