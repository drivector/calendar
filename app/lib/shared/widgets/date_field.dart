import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// A bordered, tappable date display that opens the stock date picker —
/// used wherever a sheet needs to ask "which day", not just "which time"
/// (the log-activity sheet's own Day field, and the Day view's add-block
/// sheet's start/end dates). [firstDate]/[lastDate] are left to the
/// caller rather than hard-coded, since the sensible bounds differ: a
/// manually-logged *actual* block can't be in the future, but a *planned*
/// one can.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onPick,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onPick(picked);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
        decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
        child: Text(
          value == null ? 'set day' : DateFormat('EEE, d MMM y').format(value!),
          style: AppTextStyles.label(),
        ),
      ),
    );
  }
}
