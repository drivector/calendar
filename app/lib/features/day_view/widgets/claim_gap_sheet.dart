import 'package:flutter/material.dart';

import '../../../data/mock/mock_categories.dart';
import '../../../models/untracked_gap.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';

/// Screen 6 — "Claim untracked time" (option `1c` third screen). Shown as a
/// bottom sheet over the dimmed day view.
Future<void> showClaimGapSheet(BuildContext context, UntrackedGap gap) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    isScrollControlled: true,
    builder: (context) => ClaimGapSheet(gap: gap),
  );
}

class ClaimGapSheet extends StatefulWidget {
  const ClaimGapSheet({super.key, required this.gap});

  final UntrackedGap gap;

  @override
  State<ClaimGapSheet> createState() => _ClaimGapSheetState();
}

/// Labels for screen 6's claim options — a superset of the four tracked
/// categories (Errands/Other have no [Category] of their own; they map to a
/// neutral swatch here).
const _claimOptions = ['Walking', 'Deep work', 'Meeting', 'Errands', 'Admin', 'Other'];

const _claimOptionCategoryIds = {
  'Walking': walkingCategoryId,
  'Deep work': deepWorkCategoryId,
  'Meeting': meetingsCategoryId,
  'Admin': adminCategoryId,
};

class _ClaimGapSheetState extends State<ClaimGapSheet> {
  late Duration _duration = widget.gap.duration;
  String? _selectedOption;

  static const _step = Duration(minutes: 5);

  Color _colorFor(String option) {
    final categoryId = _claimOptionCategoryIds[option];
    return categoryId == null ? AppColors.ink(0.4) : categoryById(categoryId).color;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.text, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Claim ${_formatClockTime(widget.gap.start)} – '
                    '${_formatClockTime(widget.gap.end)}',
                    style: AppTextStyles.title(),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Text('close', style: AppTextStyles.mono()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepperButton(
                    label: '–',
                    onTap: () => setState(() {
                      final next = _duration - _step;
                      if (next >= _step) _duration = next;
                    }),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                    child: Text(
                      formatDuration(_duration),
                      style: AppTextStyles.title().copyWith(fontSize: 28),
                    ),
                  ),
                  _StepperButton(
                    label: '+',
                    onTap: () => setState(() => _duration += _step),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: const SizedBox(width: double.infinity, height: 1),
              ),
              const SizedBox(height: AppSpacing.s3),
              Text('CATEGORY', style: AppTextStyles.kicker()),
              const SizedBox(height: AppSpacing.s2),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.s2,
                crossAxisSpacing: AppSpacing.s2,
                childAspectRatio: 3.4,
                children: [
                  for (final option in _claimOptions)
                    _ClaimOptionButton(
                      label: option,
                      color: _colorFor(option),
                      selected: _selectedOption == option,
                      onTap: () => setState(() => _selectedOption = option),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                "suggested: Errands — calendar had 'grocery run'",
                style: AppTextStyles.mono(),
              ),
              const SizedBox(height: AppSpacing.s3),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.centerLeft,
                  color: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                  child: Text('SAVE', style: AppTextStyles.small(color: AppColors.bg)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: AppColors.text)),
        child: Text(label, style: AppTextStyles.title()),
      ),
    );
  }
}

class _ClaimOptionButton extends StatelessWidget {
  const _ClaimOptionButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? color : AppColors.ink(0.3), width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, color: color),
            const SizedBox(width: AppSpacing.s1),
            Text(label, style: AppTextStyles.mono(color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}

String _formatClockTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
