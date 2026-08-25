import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../state/day_view_providers.dart';
import '../../../theme/app_text_styles.dart';
import 'time_body_grid.dart';

/// A small date label per visible day-column ("TUE 26"), sitting directly
/// above [TimeBodyGrid] — collapses to nothing in Day mode, since a single
/// day is already fully named by the header above. Uses the same
/// [columnLayoutsFor] helper [TimeBodyGrid] does so the two can never drift
/// out of pixel alignment with each other.
class DayColumnHeaderRow extends ConsumerWidget {
  const DayColumnHeaderRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = ref.watch(visibleDatesProvider);
    if (dates.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 28,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layouts = columnLayoutsFor(constraints.maxWidth, dates.length);
          return Stack(
            children: [
              for (var i = 0; i < dates.length; i++)
                Positioned(
                  left: layouts[i].left,
                  width: layouts[i].width,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      '${DateFormat('EEE').format(dates[i]).toUpperCase()} '
                      '${DateFormat('d').format(dates[i])}',
                      style: AppTextStyles.small(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
