import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/segmented_control.dart';
import '../../../shared/widgets/step_arrow_button.dart';
import '../../../state/day_view_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

class DayHeaderBar extends ConsumerWidget {
  const DayHeaderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final dayLayer = ref.watch(dayLayerProvider);

    void step(int deltaDays) {
      final current = ref.read(selectedDateProvider);
      ref.read(selectedDateProvider.notifier).state = current.add(
        Duration(days: deltaDays),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.text, width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StepArrowButton(
                  direction: StepDirection.previous,
                  onTap: () => step(-1),
                ),
                const SizedBox(width: AppSpacing.s2),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('EEEE').format(selectedDate).toUpperCase(),
                      style: AppTextStyles.kicker(),
                    ),
                    Text(
                      DateFormat('d MMM').format(selectedDate),
                      style: AppTextStyles.title(),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.s2),
                StepArrowButton(
                  direction: StepDirection.next,
                  onTap: () => step(1),
                ),
              ],
            ),
            SegmentedControl<DayLayer>(
              selected: dayLayer,
              onChanged: (value) =>
                  ref.read(dayLayerProvider.notifier).state = value,
              options: const [
                SegmentedOption(value: DayLayer.actual, label: 'Day'),
                SegmentedOption(
                  value: DayLayer.planAndActual,
                  label: 'Plan + actual',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
