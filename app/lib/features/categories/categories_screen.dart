import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/categories_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'widgets/category_edit_sheet.dart';

/// Category management — create, rename, recolor, and delete categories.
/// Called out in the handoff's "Not yet designed" list; built fresh here in
/// the app's own system since there was no reference wireframe for it.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return ColoredBox(
      color: AppColors.bg,
      child: SafeArea(
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
                    Text('Categories', style: AppTextStyles.title()),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Text('close', style: AppTextStyles.mono()),
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
                    for (final category in categories)
                      GestureDetector(
                        onTap: () => showCategoryEditSheet(context, ref, existing: category),
                        behavior: HitTestBehavior.opaque,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.divider)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                            child: Row(
                              children: [
                                Container(width: 12, height: 12, color: category.color),
                                const SizedBox(width: AppSpacing.s2),
                                Expanded(
                                  child: Text(category.name, style: AppTextStyles.label()),
                                ),
                                Text('edit', style: AppTextStyles.mono()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.s3),
                    GestureDetector(
                      onTap: () => showCategoryEditSheet(context, ref),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 44),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.text, width: 2),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                        child: Text(
                          '+ NEW CATEGORY',
                          style: AppTextStyles.small(color: AppColors.text),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
