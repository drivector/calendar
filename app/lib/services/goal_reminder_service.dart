import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/goal.dart';
import '../models/goal_reminders.dart';

/// Thin wrapper around [FlutterLocalNotificationsPlugin] — turns the pure
/// [computeReminderOccurrences] result into actually-scheduled OS
/// notifications. iOS and macOS only, matching the rest of the app's
/// current platform target.
class GoalReminderService {
  GoalReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(_deviceLocation());

    const settings = InitializationSettings(
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Replaces every currently-scheduled reminder with a fresh set computed
  /// from [goals] — simplest correct approach given the rolling window in
  /// [computeReminderOccurrences]: goals change infrequently, so a full
  /// cancel-and-reschedule on each change is cheap enough, and avoids
  /// having to diff old vs. new occurrences by hand.
  Future<void> resync(List<Goal> goals) async {
    await _plugin.cancelAll();

    final occurrences = computeReminderOccurrences(
      goals: goals,
      now: DateTime.now(),
    );

    for (final occurrence in occurrences) {
      await _plugin.zonedSchedule(
        occurrence.id,
        occurrence.title,
        occurrence.body,
        tz.TZDateTime.from(occurrence.scheduledTime, tz.local),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}

/// The `timezone` package has no way to ask the platform for its actual
/// zone name (that needs a separate native-channel plugin this app doesn't
/// depend on), so this finds a database location whose current UTC offset
/// matches the device's — good enough to schedule at the right wall-clock
/// time, which is all [GoalReminderService] needs. Falls back to UTC if
/// nothing matches (never happens in practice: `Etc/GMT±n` entries cover
/// every whole-hour offset).
tz.Location _deviceLocation() {
  final deviceOffset = DateTime.now().timeZoneOffset;
  for (final location in tz.timeZoneDatabase.locations.values) {
    final zoneOffset = Duration(milliseconds: location.currentTimeZone.offset);
    if (zoneOffset == deviceOffset) return location;
  }
  return tz.UTC;
}
