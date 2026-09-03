import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_categories.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../shared/widgets/inline_form_error.dart';
import '../../../state/categories_providers.dart';
import '../../../state/goals_providers.dart';
import '../../../state/running_activity_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// "Start" — picks which goal the run counts toward (same goal-first chip
/// picker `LogActivitySheet` uses) and an optional title, then writes the
/// running-activity doc. Unlike `LogActivitySheet`, there's no start/end
/// time to fill in — the block's start is simply "now."
Future<void> showStartActivitySheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (context) => StartActivitySheet(ref: ref),
  );
}

class StartActivitySheet extends ConsumerStatefulWidget {
  const StartActivitySheet({super.key, required this.ref});

  // Borrowed ref — read-only in this widget's own build, per this project's
  // Riverpod convention (see e.g. LogActivitySheet's own doc comment).
  final WidgetRef ref;

  @override
  ConsumerState<StartActivitySheet> createState() =>
      _StartActivitySheetState();
}

class _StartActivitySheetState extends ConsumerState<StartActivitySheet> {
  final _titleController = TextEditingController();
  String? _goalId;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _start() {
    final goalId = _goalId;
    if (goalId == null) {
      setState(() => _errorMessage = 'Pick a goal before starting');
      return;
    }
    final goal = widget.ref
        .read(goalsProvider)
        .firstWhere((g) => g.id == goalId);
    final title = _titleController.text.trim().isEmpty
        ? goal.name
        : _titleController.text.trim();
    startActivity(
      widget.ref,
      goalId: goal.id,
      categoryId: goal.categoryId,
      title: title,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final goals = ref.watch(goalsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DecoratedBox(
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
                    Text('Start activity', style: AppTextStyles.title()),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          behavior: HitTestBehavior.opaque,
                          child: Text('close', style: AppTextStyles.mono()),
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        GestureDetector(
                          onTap: _start,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            'Start',
                            style: AppTextStyles.mono(color: AppColors.accent),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.s3),
                  InlineFormError(_errorMessage!),
                ],
                const SizedBox(height: AppSpacing.s3),
                Text('TITLE (OPTIONAL)', style: AppTextStyles.kicker()),
                const SizedBox(height: 5),
                TextField(
                  controller: _titleController,
                  style: AppTextStyles.label(),
                  decoration: const InputDecoration(isDense: true),
                ),
                const SizedBox(height: AppSpacing.s3),
                Text('GOAL', style: AppTextStyles.kicker()),
                const SizedBox(height: 5),
                Wrap(
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s2,
                  children: [
                    for (final goal in goals.where(
                      (g) => g.categoryId != screenTimeCategoryId,
                    ))
                      CategoryChip(
                        label: goal.name.toLowerCase(),
                        color: resolveCategory(categories, goal.categoryId).color,
                        selected: _goalId == goal.id,
                        onTap: () => setState(() {
                          _goalId = goal.id;
                          _errorMessage = null;
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
