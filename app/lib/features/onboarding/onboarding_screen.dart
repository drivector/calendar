import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/onboarding_categories.dart';
import '../../models/category.dart';
import '../../state/categories_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../goals/widgets/goal_edit_sheet.dart';

/// Shown once, right after sign-up — a brand-new account has no goals to
/// track yet, so rather than dropping straight into an empty Day view,
/// this prompts creating the first one. Seeds 5 predefined categories
/// (see `data/onboarding_categories.dart`) so there's something concrete
/// to pick from instead of an empty category list blocking goal creation
/// the way it normally would for a fresh account.
///
/// Not a separate route: `AuthGate` simply renders this instead of
/// `RootShell` while the signed-in account still has zero goals, and
/// swaps to `RootShell` the instant one exists — live, via the same
/// provider this screen's own goal creation writes through. No "done"
/// button needed; creating a goal *is* what finishes onboarding.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    // Deferred: Riverpod forbids writing a provider from initState itself.
    // Only seeds if categories are currently empty — if the user deletes
    // one of these later but still hasn't created a goal (so this screen
    // shows again), that deletion should stick, not get silently undone.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(categoriesProvider).isEmpty) {
        final repo = ref.read(categoriesRepositoryProvider);
        for (final category in onboardingCategories) {
          repo.upsert(category);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The *live* list, not the static onboardingCategories constant —
    // seeding only ever happens once, while categories are still empty
    // (see initState), so an account that already has its own category
    // (having deleted the predefined ones, say) shows that instead of
    // chips for categories that don't actually exist.
    final categories = ref.watch(categoriesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome to Track My Day', style: AppTextStyles.title()),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'Start by creating a goal for something you want to track.',
            style: AppTextStyles.mono(),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text('Pick a category to get started', style: AppTextStyles.kicker()),
          const SizedBox(height: AppSpacing.s2),
          for (final category in categories)
            _CategoryOption(
              category: category,
              description: onboardingCategoryDescriptions[category.id],
              onTap: () => showGoalEditSheet(
                context,
                ref,
                initialCategoryId: category.id,
              ),
            ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'You can add more goals and categories any time from the Goals tab.',
            style: AppTextStyles.mono(),
          ),
        ],
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.description,
    required this.onTap,
  });

  final Category category;
  final String? description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 3, height: 32, color: category.color),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.name, style: AppTextStyles.label()),
                    if (description != null)
                      Text(description!, style: AppTextStyles.mono()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
