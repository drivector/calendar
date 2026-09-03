import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/running_activity_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';
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
    // Forces this widget to rebuild once a second while something's
    // running — see liveActivityTickProvider's own doc comment. Nothing
    // reads its value; it exists purely to make `elapsed` below actually
    // count up instead of only updating whenever something unrelated
    // happens to rebuild this widget.
    ref.watch(liveActivityTickProvider);
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

    // Recomputed fresh every rebuild — the liveActivityTickProvider watch
    // above is what makes that happen once a second while running, rather
    // than only whenever something unrelated (a Firestore change,
    // navigating tabs, ...) happens to rebuild this widget.
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
          '■ ${formatElapsedClock(elapsed)} Stop',
          style: AppTextStyles.small(color: AppColors.surface),
        ),
      ),
    );
  }
}
