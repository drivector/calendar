import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/goal_reminder_service.dart';

/// One [GoalReminderService] per app run — holds the underlying platform
/// plugin's state (initialized or not), so it has to be a singleton rather
/// than recreated per rebuild.
final goalReminderServiceProvider = Provider<GoalReminderService>((ref) {
  return GoalReminderService();
});
