import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AppTabBarItem {
  const AppTabBarItem(this.label);

  final String label;
}

/// The 4-cell "DAY | WEEK | GOALS | + LOG" bottom bar: 2px top rule, 1px
/// right divider between cells, active tab in the accent, inactive at 40%
/// ink. Every cell keeps a >=44pt tap target regardless of its visual size.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<AppTabBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.text, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: i < items.length - 1
                        ? Border(right: BorderSide(color: AppColors.divider))
                        : null,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 8,
                      ),
                      child: Text(
                        items[i].label.toUpperCase(),
                        style: AppTextStyles.tabLabel(
                          color: i == currentIndex
                              ? AppColors.accent
                              : AppColors.ink(0.4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
