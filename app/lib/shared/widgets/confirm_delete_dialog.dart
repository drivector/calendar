import 'package:flutter/material.dart' show Dialog, showDialog;
import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Asks "are you sure?" before a destructive action — unlike this app's
/// existing "Delete goal"/"Delete category" rows (which act immediately,
/// with no prompt), deleting an *activity* asks first. Returns `true` only
/// if the user tapped Delete; `false` for Cancel or dismissing the dialog
/// any other way (barrier tap, back gesture).
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _ConfirmDeleteDialog(title: title, message: message),
  );
  return confirmed ?? false;
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
      child: DecoratedBox(
        decoration: const BoxDecoration(borderRadius: AppShapes.medium),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.title()),
              const SizedBox(height: AppSpacing.s1),
              Text(message, style: AppTextStyles.mono()),
              const SizedBox(height: AppSpacing.s4),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(true),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: AppShapes.small,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3,
                  ),
                  child: Text(
                    'Delete',
                    style: AppTextStyles.small(color: AppColors.surface),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.text),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3,
                  ),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.small(color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
