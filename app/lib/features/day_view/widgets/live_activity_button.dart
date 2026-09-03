import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/running_activity_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import 'start_activity_sheet.dart';

/// "▶ Start" when nothing's running; once something is, becomes a single
/// tappable pill showing the elapsed time that **registers the run and
/// stops it in one tap** — no separate confirm step, matching every other
/// single-action save point in this app (e.g. "+ Log"'s own SAVE). The
/// running state itself lives in Firestore (`runningActivityProvider`),
/// not any local field here, so it's already showing correctly the moment
/// this widget first builds after a cold app launch — that's what makes
/// "exit the app and find it running when you re-enter" work.
class LiveActivityButton extends ConsumerWidget {
  const LiveActivityButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(runningActivityProvider);
    if (running == null) {
      return GestureDetector(
        onTap: () => showStartActivitySheet(context, ref),
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.neutral500),
            borderRadius: AppShapes.small,
          ),
          child: Text('▶ Start', style: AppTextStyles.small(color: AppColors.text)),
        ),
      );
    }

    // No self-driven per-second ticker on purpose — a repeating Timer/
    // Stream tied to a widget shown on every screen would fire for as long
    // as something is running, which is exactly the kind of timer
    // flutter_test's `pumpAndSettle` (used throughout this app's test
    // suite) can never settle around. Elapsed is instead computed fresh at
    // whatever moment this widget happens to rebuild (a Firestore change,
    // navigating tabs, ...) — not literally live to the second, but never
    // stale by more than that, and with no risk of a runaway timer.
    final elapsed = DateTime.now().difference(running.startedAt);

    return GestureDetector(
      onTap: () => stopActivity(ref, running),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
        decoration: const BoxDecoration(
          color: AppColors.accent,
          borderRadius: AppShapes.small,
        ),
        child: Text(
          '■ ${_formatElapsed(elapsed)} Stop',
          style: AppTextStyles.small(color: AppColors.surface),
        ),
      ),
    );
  }
}

/// "12:34" (mm:ss) below an hour, "1:02:34" (h:mm:ss) once it runs long —
/// a live stopwatch reads seconds, unlike this app's usual "1h 45m" format
/// for a completed duration.
String _formatElapsed(Duration elapsed) {
  final totalSeconds = elapsed.inSeconds.abs();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}
