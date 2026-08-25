import 'package:flutter/widgets.dart';

import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// A validation error shown inline within a sheet's own layout, not a
/// `SnackBar`. A `SnackBar` attaches to the app-root `ScaffoldMessenger`,
/// which sits *below* a modal bottom sheet's own overlay route — while the
/// sheet is open, the SnackBar still "shows" (present in the widget tree)
/// but renders behind the sheet, invisible. This is always visible, since
/// it's part of the sheet's own content, not a separate overlay racing it.
/// Fluent `dangerForeground1`.
const _errorRed = Color(0xFFB10E1C);

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
      // Fluent's error styling is a red-tinted surface with a matching
      // stroke, not the brand colour — an error shouldn't read as the same
      // signal as a primary action now that the accent is blue.
      decoration: BoxDecoration(
        color: const Color(0xFFFDF3F4),
        border: Border.all(color: _errorRed),
        borderRadius: AppShapes.small,
      ),
      child: Text(message, style: AppTextStyles.label(color: _errorRed)),
    );
  }
}
