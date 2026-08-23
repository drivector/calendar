import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/dummy_data.dart';
import '../data/mock/mock_categories.dart';
import '../models/category.dart';
import '../theme/app_colors.dart';

class CategoriesNotifier extends StateNotifier<List<Category>> {
  CategoriesNotifier() : super([...mockCategories, ...dummyCategories]);

  void addCategory(Category category) => state = [...state, category];

  void updateCategory(Category updated) => state = [
        for (final category in state)
          if (category.id == updated.id) updated else category,
      ];

  void removeCategory(String id) =>
      state = state.where((category) => category.id != id).toList();
}

final categoriesProvider = StateNotifierProvider<CategoriesNotifier, List<Category>>(
  (ref) => CategoriesNotifier(),
);

const _unknownCategory = Category(
  id: 'unknown',
  name: 'Unknown',
  color: AppColors.neutral500,
);

/// Resolves a category by id against a live [categories] list, falling back
/// to a neutral placeholder if it's been deleted since a block referenced it.
Category resolveCategory(List<Category> categories, String id) {
  for (final category in categories) {
    if (category.id == id) return category;
  }
  return _unknownCategory;
}

/// A curated palette at the design system's fixed lightness/chroma
/// (`oklch(0.58 0.19 <hue>)`) — new categories pick from these rather than
/// a free-form color picker, keeping every category visually consistent
/// with the existing ones.
const categoryColorPalette = [
  AppColors.accent, // pinned red, hue ~15
  Color(0xFFCD4B00), // orange, hue 50
  Color(0xFF009520), // green, hue 145
  Color(0xFF0097A6), // teal, hue 200
  Color(0xFF0278E7), // blue, hue 255
  Color(0xFF8E57D8), // purple, hue 300
  Color(0xFFA94BBE), // magenta, hue 320
];
