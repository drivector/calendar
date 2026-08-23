import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_categories.dart';
import '../../data/mock/mock_goals.dart';
import '../../models/tracked_block.dart';
import '../../shared/widgets/category_chip.dart';
import '../../state/categories_providers.dart';
import '../../state/day_view_providers.dart';
import '../../state/log_entry_providers.dart';
import '../../state/root_shell_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/duration_format.dart';

/// Screen 5 — "Log activity (manual entry)" (option #2a). Saving actually
/// creates a [TrackedBlock] for the currently selected day now — it used to
/// just reset the form without persisting anything.
class LogActivityScreen extends ConsumerWidget {
  const LogActivityScreen({super.key});

  void _save(WidgetRef ref) {
    final draft = ref.read(draftLogEntryProvider);
    final start = draft.start;
    final end = draft.end;
    final categoryId = draft.categoryId;

    if (start != null && end != null && categoryId != null) {
      final date = ref.read(selectedDateProvider);
      final startDt = DateTime(date.year, date.month, date.day, start.hour, start.minute);
      var endDt = DateTime(date.year, date.month, date.day, end.hour, end.minute);
      if (!endDt.isAfter(startDt)) endDt = endDt.add(const Duration(days: 1));

      final categories = ref.read(categoriesProvider);
      final category = resolveCategory(categories, categoryId);
      final title = draft.activity.trim().isEmpty ? category.name : draft.activity.trim();

      ref.read(allTrackedBlocksProvider.notifier).addBlock(
            TrackedBlock(
              id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
              start: startDt,
              end: endDt,
              title: title,
              categoryId: categoryId,
              sourceId: 'manual',
            ),
          );
    }

    ref.read(draftLogEntryProvider.notifier).reset();
    ref.read(currentTabIndexProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(draftLogEntryProvider);
    final notifier = ref.read(draftLogEntryProvider.notifier);
    final categories = ref.watch(categoriesProvider);
    final countsToward = draft.categoryId == null
        ? null
        : goalForCategory(draft.categoryId!);

    return ColoredBox(
      color: AppColors.bg,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.text, width: 2)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Log activity', style: AppTextStyles.title()),
                  GestureDetector(
                    onTap: notifier.reset,
                    behavior: HitTestBehavior.opaque,
                    child: Text('cancel', style: AppTextStyles.mono()),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Activity'),
                  TextField(
                    style: AppTextStyles.label(),
                    decoration: const InputDecoration(isDense: true),
                    onChanged: notifier.setActivity,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          label: 'Start',
                          value: draft.start,
                          onPick: notifier.setStart,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: _TimeField(
                          label: 'End',
                          value: draft.end,
                          onPick: notifier.setEnd,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _FieldLabel('Duration'),
                  Text(
                    draft.duration == null
                        ? '—'
                        : formatDuration(draft.duration!),
                    style: AppTextStyles.title().copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.divider)),
                    ),
                    child: const SizedBox(width: double.infinity, height: 1),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _FieldLabel('Category'),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: [
                      // Screen 5's chip row is walking/deep work/meeting/admin
                      // only — "screen time" is auto-tracked, not something
                      // you'd manually log.
                      for (final category in categories.where(
                        (c) => c.id != screenTimeCategoryId,
                      ))
                        CategoryChip(
                          label: category.name.toLowerCase(),
                          color: category.color,
                          selected: draft.categoryId == category.id,
                          onTap: () => notifier.setCategory(category.id),
                        ),
                      CategoryChip(
                        label: '+',
                        color: AppColors.text,
                        selected: false,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _FieldLabel('Counts toward'),
                  Text(
                    countsToward == null
                        ? '—'
                        : '${countsToward.name} ${countsToward.weeklyTargetHours.toStringAsFixed(0)} h/wk',
                    style: AppTextStyles.mono(color: AppColors.text),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _FieldLabel('Note'),
                  TextField(
                    minLines: 3,
                    maxLines: 5,
                    style: AppTextStyles.label(),
                    decoration: const InputDecoration(isDense: true),
                    onChanged: notifier.setNote,
                  ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.text, width: 2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _save(ref),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.centerLeft,
                      color: AppColors.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s3,
                      ),
                      child: Text(
                        'SAVE ENTRY',
                        style: AppTextStyles.small(color: AppColors.bg),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    'or hold the + tab to start a live timer',
                    style: AppTextStyles.mono(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text.toUpperCase(), style: AppTextStyles.kicker()),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel(label),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: value ?? TimeOfDay.now(),
            );
            if (picked != null) onPick(picked);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              value == null ? 'Set $label'.toLowerCase() : value!.format(context),
              style: AppTextStyles.label(),
            ),
          ),
        ),
      ],
    );
  }
}
