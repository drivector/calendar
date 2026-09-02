import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/goal_progress.dart';
import '../../shared/widgets/date_swipe_nav.dart';
import '../../shared/widgets/step_arrow_button.dart';
import '../../state/day_view_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'capacity_view.dart';

/// Capacity's own top-level tab — promoted out from under Account's
/// segmented control since planned-vs-available is checked often enough to
/// want one tap rather than two. Steps a full week at a time (arrows or a
/// swipe, same gesture the Day view uses for its own date), rather than
/// switching bottom tabs the way Goals/Account's swipe does — Capacity now
/// has its own timeline to move through instead.
class CapacityScreen extends ConsumerWidget {
  const CapacityScreen({super.key});

  void _stepWeek(WidgetRef ref, {required bool forward}) {
    final current = ref.read(selectedDateProvider);
    ref.read(selectedDateProvider.notifier).state = current.add(
      Duration(days: forward ? 7 : -7),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final weekStart = weekStartFor(selectedDate);
    final weekEnd = weekStart.add(const Duration(days: 6));

    return DateSwipeNav(
      onPrevious: () => _stepWeek(ref, forward: false),
      onNext: () => _stepWeek(ref, forward: true),
      child: ColoredBox(
        color: AppColors.bg,
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s2,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    StepArrowButton(
                      direction: StepDirection.previous,
                      onTap: () => _stepWeek(ref, forward: false),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('PLANNING', style: AppTextStyles.kicker()),
                          Text(
                            '${DateFormat('d MMM').format(weekStart)} – '
                            '${DateFormat('d MMM').format(weekEnd)}',
                            style: AppTextStyles.title(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    StepArrowButton(
                      direction: StepDirection.next,
                      onTap: () => _stepWeek(ref, forward: true),
                    ),
                  ],
                ),
              ),
            ),
            const Expanded(child: CapacityView()),
          ],
        ),
      ),
    );
  }
}
