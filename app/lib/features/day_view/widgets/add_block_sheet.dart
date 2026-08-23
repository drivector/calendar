import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/planned_block.dart';
import '../../../models/tracked_block.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../state/categories_providers.dart';
import '../../../state/day_view_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/time_of_day_utils.dart';

/// Tapping empty space in either lane of the Day view timeline opens this —
/// a quick add form for a new planned or actual entry, prefilled with the
/// tapped time.
Future<void> showAddBlockSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool isPlan,
  required TimeOfDay initialStart,
}) {
  // Nothing to file a block under yet — a brand-new account starts with no
  // categories, so tell the user to create one first rather than opening a
  // form with no valid default.
  if (ref.read(categoriesProvider).isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create a category first')),
    );
    return Future.value();
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    isScrollControlled: true,
    builder: (context) => _AddBlockSheet(isPlan: isPlan, initialStart: initialStart, ref: ref),
  );
}

class _AddBlockSheet extends StatefulWidget {
  const _AddBlockSheet({
    required this.isPlan,
    required this.initialStart,
    required this.ref,
  });

  final bool isPlan;
  final TimeOfDay initialStart;
  final WidgetRef ref;

  @override
  State<_AddBlockSheet> createState() => _AddBlockSheetState();
}

class _AddBlockSheetState extends State<_AddBlockSheet> {
  late final _titleController = TextEditingController();
  late TimeOfDay _start = widget.initialStart;
  late TimeOfDay _end = addMinutes(widget.initialStart, 30);
  late String _categoryId = widget.ref.read(categoriesProvider).first.id;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _save() {
    final selectedDate = widget.ref.read(selectedDateProvider);
    final startDt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      _start.hour,
      _start.minute,
    );
    var endDt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      _end.hour,
      _end.minute,
    );
    if (!endDt.isAfter(startDt)) endDt = endDt.add(const Duration(days: 1));

    final categories = widget.ref.read(categoriesProvider);
    final category = resolveCategory(categories, _categoryId);
    final title = _titleController.text.trim().isEmpty
        ? category.name
        : _titleController.text.trim();
    final id = '${widget.isPlan ? 'plan' : 'actual'}-${DateTime.now().microsecondsSinceEpoch}';

    if (widget.isPlan) {
      widget.ref.read(plannedBlocksRepositoryProvider).upsert(
            PlannedBlock(id: id, start: startDt, end: endDt, title: title, categoryId: _categoryId),
          );
    } else {
      widget.ref.read(trackedBlocksRepositoryProvider).upsert(
            TrackedBlock(
              id: id,
              start: startDt,
              end: endDt,
              title: title,
              categoryId: _categoryId,
              sourceId: 'manual',
            ),
          );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // A read, not a watch — see the note on the same pattern in
    // GoalEditSheet: this ref belongs to the widget that opened this sheet.
    final categories = widget.ref.read(categoriesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DecoratedBox(
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
                      widget.isPlan ? 'New planned activity' : 'New actual activity',
                      style: AppTextStyles.title(),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Text('cancel', style: AppTextStyles.mono()),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                _Label('Title'),
                TextField(
                  controller: _titleController,
                  style: AppTextStyles.label(),
                  decoration: const InputDecoration(isDense: true),
                ),
                const SizedBox(height: AppSpacing.s3),
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(label: 'Start', value: _start, onTap: () => _pickTime(true)),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: _TimeField(label: 'End', value: _end, onTap: () => _pickTime(false)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                _Label('Category'),
                Wrap(
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s2,
                  children: [
                    for (final category in categories)
                      CategoryChip(
                        label: category.name.toLowerCase(),
                        color: category.color,
                        selected: _categoryId == category.id,
                        onTap: () => setState(() => _categoryId = category.id),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                GestureDetector(
                  onTap: _save,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.centerLeft,
                    color: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                    child: Text(
                      widget.isPlan ? 'ADD PLAN' : 'ADD ACTUAL',
                      style: AppTextStyles.small(color: AppColors.bg),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

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
  const _TimeField({required this.label, required this.value, required this.onTap});

  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Label(label),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
            decoration: BoxDecoration(border: Border.all(color: AppColors.divider)),
            child: Text(value.format(context), style: AppTextStyles.label()),
          ),
        ),
      ],
    );
  }
}
