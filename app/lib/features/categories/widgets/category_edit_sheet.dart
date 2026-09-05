import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/category.dart';
import '../../../shared/widgets/inline_form_error.dart';
import '../../../state/categories_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shapes.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// Create or edit a category. Pass [existing] to edit it in place (with a
/// delete option); omit it to create a new one.
Future<void> showCategoryEditSheet(
  BuildContext context,
  WidgetRef ref, {
  Category? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (context) => _CategoryEditSheet(existing: existing, ref: ref),
  );
}

class _CategoryEditSheet extends StatefulWidget {
  const _CategoryEditSheet({this.existing, required this.ref});

  final Category? existing;
  final WidgetRef ref;

  @override
  State<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<_CategoryEditSheet> {
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late Color _color = widget.existing?.color ?? categoryColorPalette.first;

  // Set only by a failed write — the form itself can't be invalid (a blank
  // name falls back to "Untitled category"). Inline rather than a SnackBar,
  // which would render behind this sheet: see InlineFormError.
  String? _saveError;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final category = Category(
      id:
          widget.existing?.id ??
          'category-${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty
          ? 'Untitled category'
          : _nameController.text.trim(),
      color: _color,
    );
    try {
      await widget.ref.read(categoriesRepositoryProvider).upsert(category);
    } catch (_) {
      // Unawaited before, so a rejected write closed the sheet with
      // nothing created and nothing said.
      if (mounted) setState(() => _saveError = kSaveFailedMessage);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _delete() {
    widget.ref.read(categoriesRepositoryProvider).remove(widget.existing!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
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
                    Text(
                      _isEditing ? 'Edit category' : 'New category',
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
                _Label('Name'),
                TextField(
                  controller: _nameController,
                  style: AppTextStyles.label(),
                  decoration: const InputDecoration(isDense: true),
                ),
                const SizedBox(height: AppSpacing.s3),
                _Label('Color'),
                Wrap(
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s2,
                  children: [
                    for (final color in categoryColorPalette)
                      GestureDetector(
                        onTap: () => setState(() => _color = color),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          color: color,
                          child: _color == color ? const _CheckMark() : null,
                        ),
                      ),
                  ],
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: AppSpacing.s3),
                  InlineFormError(_saveError!),
                ],
                const SizedBox(height: AppSpacing.s4),
                GestureDetector(
                  onTap: _save,
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
                      _isEditing ? 'Save changes' : 'Create category',
                      style: AppTextStyles.small(color: AppColors.surface),
                    ),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: AppSpacing.s2),
                  GestureDetector(
                    onTap: _delete,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Delete category',
                        style: AppTextStyles.small(color: AppColors.accent),
                      ),
                    ),
                  ),
                ],
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

class _CheckMark extends StatelessWidget {
  const _CheckMark();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CheckPainter(), size: const Size(14, 10));
  }
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.bg
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..lineTo(size.width * 0.4, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => false;
}
