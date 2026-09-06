import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:flutter/widgets.dart';

import '../../../models/planned_block.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// What tapping a planned block on the Day view timeline can lead to.
enum PlanBlockAction {
  /// Edit the plan itself — this exact block, in place.
  editPlan,

  /// Add a *second* plan in the same slot, rather than changing this one.
  newPlan,

  /// Register what actually happened, prefilled from the plan.
  newActual,
}

/// Tapping a planned block used to jump straight to one of these three
/// without asking, picked from whether the plan had already started —
/// which meant a plan in the past could only ever be logged against, never
/// edited (the bug the user hit: tapping "sleep" to correct it opened a new
/// actual entry instead). The choice is the user's to make, so it's asked
/// rather than inferred; [PlanBlockAction.editPlan] is listed first as the
/// one the tap most often means.
///
/// Returns null if the sheet is dismissed without choosing.
Future<PlanBlockAction?> showPlanBlockActionsSheet(
  BuildContext context, {
  required PlannedBlock block,
}) {
  return showModalBottomSheet<PlanBlockAction>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (context) => _PlanBlockActionsSheet(block: block),
  );
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _PlanBlockActionsSheet extends StatelessWidget {
  const _PlanBlockActionsSheet({required this.block});

  final PlannedBlock block;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        borderRadius: AppShapes.sheetTop,
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
                  Flexible(
                    child: Text(
                      block.title,
                      style: AppTextStyles.title(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 32,
                      ),
                      alignment: Alignment.centerRight,
                      child: Text('close', style: AppTextStyles.mono()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Planned ${_clock(block.start)}–${_clock(block.end)}',
                style: AppTextStyles.mono(),
              ),
              const SizedBox(height: AppSpacing.s3),
              _ActionRow(
                // A goal's own recurring schedule has no standalone
                // document to edit, so editing that kind of plan means
                // going to where the schedule actually lives.
                // Each row names the sheet it opens, so the choice reads
                // as the same vocabulary the destination uses.
                label: block.isGoalGenerated
                    ? 'Edit goal schedule'
                    : 'Edit planned activity',
                action: PlanBlockAction.editPlan,
              ),
              const SizedBox(height: AppSpacing.s2),
              _ActionRow(
                label: 'New planned activity',
                action: PlanBlockAction.newPlan,
              ),
              const SizedBox(height: AppSpacing.s2),
              _ActionRow(
                label: 'New actual activity',
                action: PlanBlockAction.newActual,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, required this.action});

  final String label;
  final PlanBlockAction action;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(action),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neutral500),
          borderRadius: AppShapes.small,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
        child: Text(label, style: AppTextStyles.small(color: AppColors.text)),
      ),
    );
  }
}
