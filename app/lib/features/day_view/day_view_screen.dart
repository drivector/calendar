import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import 'widgets/day_column_header_row.dart';
import 'widgets/day_header_bar.dart';
import 'widgets/drift_footer.dart';
import 'widgets/legend_row.dart';
import 'widgets/time_body_grid.dart';

/// Screen 1 — "Day view: plan + actual" (option #3a), the app's primary
/// screen. The bottom tab bar is hosted by [RootShell], not this screen.
class DayViewScreen extends StatelessWidget {
  const DayViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg,
      child: Column(
        children: [
          const DayHeaderBar(),
          const LegendRow(),
          const DayColumnHeaderRow(),
          const Expanded(child: TimeBodyGrid()),
          const DriftFooter(),
        ],
      ),
    );
  }
}
