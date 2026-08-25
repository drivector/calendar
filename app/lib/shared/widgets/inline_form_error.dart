import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// A validation error shown inline within a sheet's own layout, not a
/// `SnackBar`. A `SnackBar` attaches to the app-root `ScaffoldMessenger`,
/// which sits *below* a modal bottom sheet's own overlay route — while the
/// sheet is open, the SnackBar still "shows" (present in the widget tree)
/// but renders behind the sheet, invisible. This is always visible, since
/// it's part of the sheet's own content, not a separate overlay racing it.
class InlineFormError extends StatelessWidget {
  const InlineFormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent100,
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
      child: Text(message, style: AppTextStyles.mono(color: AppColors.accent)),
    );
  }
}
