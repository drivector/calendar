import 'package:flutter/material.dart' show Dialog, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/category.dart';
import '../../../models/tracked_block.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/dashed_border.dart';
import '../../../state/day_view_providers.dart';
import '../../../theme/app_category_colors.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/duration_format.dart';
import '../../log_activity/widgets/log_activity_sheet.dart';
import 'block_label_style.dart';

/// A tracked block, styled like an Outlook calendar event chip: rounded,
/// a pale category tint, a solid category bar down the left edge, subject
/// on top and a quieter source line beneath. Tapping opens a detail sheet.
/// When [wasPlanned] is true — see [trackedBlockWasPlanned], which covers
/// both an explicit link via [TrackedBlock.plannedBlockId] (the goal
/// list's "complete" button) and an entry logged by hand that simply
/// overlaps a planned block in the same category — a dashed outline wraps
/// the whole block too, the same dashed language [PlanBlockWidget] uses,
/// so "this was planned, and it happened" reads as one combined signal
/// rather than the solid fill alone silently swallowing that it was ever
/// planned.
class ActualBlockWidget extends StatelessWidget {
  const ActualBlockWidget({
    super.key,
    required this.block,
    required this.category,
    required this.wasPlanned,
    required this.ref,
    required this.labelStyle,
  });

  final TrackedBlock block;
  final Category category;
  final bool wasPlanned;

  // Borrowed from the caller (time_body_grid.dart), not this widget's own
  // — per this repo's Riverpod convention, only ever .read() from it, and
  // only inside callbacks, never .watch() during build.
  final WidgetRef ref;

  // How much text this block's own real, unclamped height has room for —
  // see [BlockLabelStyle]'s own doc comment.
  final BlockLabelStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final durationLabel = formatDuration(block.duration);
    Widget? label;
    switch (labelStyle) {
      case BlockLabelStyle.full:
        label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              block.title,
              // Outlook sets an event's subject a notch heavier than body
              // text, with the secondary line beneath it staying quiet.
              style: AppTextStyles.label().copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$durationLabel · (${block.sourceId})',
              style: AppTextStyles.mono(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      case BlockLabelStyle.compact:
        label = Text(
          '$durationLabel · ${block.title}',
          style: AppTextStyles.mono(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case BlockLabelStyle.hidden:
        // Too short for even one line — a plain colored bar, no text,
        // rather than clipped, illegible characters.
        label = null;
    }
    final content = Container(
      alignment: labelStyle == BlockLabelStyle.full
          ? Alignment.topLeft
          : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppCategoryColors.blockFill(category.color),
        border: Border(left: BorderSide(color: category.color, width: 3)),
        borderRadius: AppShapes.small,
      ),
      padding: label == null
          ? EdgeInsets.zero
          : const EdgeInsets.all(AppSpacing.s1),
      // maxLines/ellipsis throughout — a narrow multi-day column (Working
      // week/Week mode) is narrow enough that unbounded text would wrap
      // onto more lines than the block's own height fits, overflowing it.
      child: label,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showDetailSheet(context, ref, block),
      child: wasPlanned
          ? DashedRectBorder(color: category.color, child: content)
          : content,
    );
  }
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

void _showDetailSheet(BuildContext context, WidgetRef ref, TrackedBlock block) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => _DetailDialog(ref: ref, block: block),
  );
}

/// A centered dialog, not a bottom sheet — sized to its own content (just
/// title, date, and time/duration) rather than stretched to any fixed
/// fraction of the screen, matching [showConfirmDeleteDialog]'s own
/// styling.
class _DetailDialog extends StatelessWidget {
  const _DetailDialog({required this.ref, required this.block});

  final WidgetRef ref;
  final TrackedBlock block;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppShapes.medium),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    block.title,
                    style: AppTextStyles.title(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _DetailIconButton(
                  glyph: '✎',
                  onTap: () {
                    Navigator.of(context).pop();
                    showLogActivitySheet(context, ref, existing: block);
                  },
                ),
                _DetailIconButton(
                  glyph: '🗑',
                  onTap: () async {
                    final confirmed = await showConfirmDeleteDialog(
                      context,
                      title: 'Delete activity?',
                      message:
                          'This removes "${block.title}" from your activity log.',
                    );
                    if (!confirmed || !context.mounted) return;
                    await softDeleteTrackedBlock(ref, block);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              DateFormat('EEE, d MMM y').format(block.start),
              style: AppTextStyles.mono(),
            ),
            const SizedBox(height: 2),
            Text(
              '${_clock(block.start)}–${_clock(block.end)} · '
              '${formatDuration(block.duration)}',
              style: AppTextStyles.mono(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bare glyph button — no box, matching [StepArrowButton]'s own "Outlook
/// doesn't box these" convention. The 32×32 footprint is still the real
/// tap target even without a visible border.
class _DetailIconButton extends StatelessWidget {
  const _DetailIconButton({required this.glyph, required this.onTap});

  final String glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Text(
            glyph,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
