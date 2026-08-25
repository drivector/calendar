import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AppTabBarItem {
  const AppTabBarItem(this.label);

  final String label;
}

/// The bottom tab bar: a white surface separated from the content by a
/// hairline, active tab in Outlook blue, inactive in secondary ink. Every
/// cell keeps a >=44pt tap target regardless of its visual size.
///
/// No per-cell dividers — Outlook's bottom bar separates tabs by spacing
/// and colour, not rules.
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
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
                      items[i].label,
                      style: AppTextStyles.tabLabel(
                        color: i == currentIndex
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ).copyWith(
                        fontWeight: i == currentIndex
                            ? FontWeight.w600
                            : FontWeight.w500,
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
