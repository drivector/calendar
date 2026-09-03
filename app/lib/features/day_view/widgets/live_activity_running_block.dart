import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/category.dart';
import '../../../models/running_activity.dart';
import '../../../state/running_activity_providers.dart';
import '../../../theme/app_category_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';
import 'block_label_style.dart';

/// The currently in-progress activity, drawn on the timeline for whichever
/// day column it started on — a real block from the moment it starts, not
/// something that only appears once it's stopped and registered. Tapping
/// it stops the run, the same one-tap-registers-and-stops behavior as the
/// header's own live pill (see `LiveActivityButton`'s own doc comment) —
/// this is just a second place to reach that same action, not a separate
/// control.
class LiveActivityRunningBlock extends ConsumerWidget {
  const LiveActivityRunningBlock({
    super.key,
    required this.running,
    required this.category,
    required this.labelStyle,
  });

  final RunningActivity running;
  final Category category;
  final BlockLabelStyle labelStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ticks once a second while running — see liveActivityTickProvider's
    // own doc comment — which is what makes this block actually grow
    // taller over time instead of freezing at whatever length it had the
    // moment this widget first built.
    ref.watch(liveActivityTickProvider);
    final elapsed = DateTime.now().difference(running.startedAt);

    Widget label;
    switch (labelStyle) {
      case BlockLabelStyle.full:
        label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              running.title,
              style: AppTextStyles.label().copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '● ${formatElapsedClock(elapsed)}',
              style: AppTextStyles.mono(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      case BlockLabelStyle.compact:
        label = OverflowBox(
          minHeight: 0,
          maxHeight: double.infinity,
          alignment: Alignment.topLeft,
          child: Text(
            '● ${formatElapsedClock(elapsed)} · ${running.title}',
            style: AppTextStyles.mono(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => stopActivity(ref, running),
      child: Container(
        alignment: labelStyle == BlockLabelStyle.full
            ? Alignment.topLeft
            : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppCategoryColors.blockFill(category.color),
          border: Border(left: BorderSide(color: category.color, width: 3)),
          borderRadius: AppShapes.small,
        ),
        padding: const EdgeInsets.all(AppSpacing.s1),
        child: label,
      ),
    );
  }
}
