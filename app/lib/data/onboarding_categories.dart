import 'package:flutter/widgets.dart';

import '../models/category.dart';

/// The categories a brand-new account is seeded with, so onboarding has
/// something concrete to build goals against instead of an empty list.
/// Colors are the same fixed-lightness/chroma OKLCH family the rest of the
/// app's category colors come from (`oklch(0.58 0.19 <hue>)` — see
/// `theme/app_category_colors.dart`), computed the same way; House
/// cleaning and Sleep are the deliberate exceptions, both dropping
/// lightness (to 0.42 and 0.45) to read as genuinely *darker* shades
/// rather than just different hues, since that was the actual
/// requirement each time ("dark purple", and sleep's own night-time mood).
///
/// Fixed ids (not generated) so re-seeding — which only ever happens while
/// the account still has zero goals, see `OnboardingScreen` — is a no-op
/// once these already exist, rather than creating duplicates.
const onboardingCategories = [
  Category(
    id: 'onboarding-work',
    name: 'Work',
    color: Color(0xFF0278E7),
  ), // oklch(0.58 0.19 255)
  Category(
    id: 'onboarding-exercise',
    name: 'Exercise',
    color: Color(0xFF009520), // oklch(0.58 0.19 145)
  ),
  Category(
    id: 'onboarding-leisure',
    name: 'Leisure',
    color: Color(0xFF0089D3), // oklch(0.58 0.19 230)
  ),
  Category(
    id: 'onboarding-art',
    name: 'Art',
    color: Color(0xFF8E57D8),
  ), // oklch(0.58 0.19 300)
  Category(
    id: 'onboarding-house-cleaning',
    name: 'House cleaning',
    color: Color(0xFF6022A2), // oklch(0.42 0.19 300)
  ),
  Category(
    id: 'onboarding-sleep',
    name: 'Sleep',
    color: Color(0xFF3D3FBB), // oklch(0.45 0.19 275) — a deep night indigo
  ),
  Category(
    id: 'onboarding-social',
    name: 'Social',
    color: Color(0xFFD33949), // oklch(0.58 0.19 20)
  ),
  Category(
    id: 'onboarding-learning',
    name: 'Learning',
    color: Color(0xFFBE409D), // oklch(0.58 0.19 340)
  ),
  Category(
    id: 'onboarding-admin',
    name: 'Admin',
    color: Color(0xFFBE5D00), // oklch(0.58 0.19 70)
  ),
];

/// A one-line explanation of what each predefined category is for, shown
/// under its name during onboarding — plain UI copy, not a persisted
/// [Category] field, so it only ever exists for these 9 and doesn't need
/// a model/schema change to support categories a user creates themselves.
/// Keyed by the same fixed ids as [onboardingCategories].
const onboardingCategoryDescriptions = {
  'onboarding-work': 'Job, meetings, and focused work time.',
  'onboarding-exercise': 'Workouts, walks, and anything active.',
  'onboarding-leisure': 'Downtime, hobbies, and relaxing.',
  'onboarding-art': 'Creative projects — drawing, music, writing.',
  'onboarding-house-cleaning': 'Chores and keeping your space tidy.',
  'onboarding-sleep': 'Time spent asleep.',
  'onboarding-social': 'Time with family and friends.',
  'onboarding-learning': 'Reading, courses, and building new skills.',
  'onboarding-admin': 'Bills, paperwork, errands, and other life admin.',
};
