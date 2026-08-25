import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firestore/firestore_list_repository.dart';
import '../models/category.dart';
import '../theme/app_colors.dart';
import 'firestore_providers.dart';

final categoriesRepositoryProvider =
    Provider<FirestoreListRepository<Category>>((ref) {
      return FirestoreListRepository<Category>(
        firestore: ref.watch(firestoreProvider),
        uid: ref.watch(currentUidProvider),
        collectionName: 'categories',
        fromMap: Category.fromMap,
        toMap: (category) => category.toMap(),
        idOf: (category) => category.id,
      );
    });

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoriesRepositoryProvider).watchAll();
});

/// The signed-in user's categories, live from Firestore — empty for a
/// brand-new account, and while the first snapshot is still loading.
final categoriesProvider = Provider<List<Category>>((ref) {
  return ref.watch(categoriesStreamProvider).valueOrNull ?? [];
});

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

/// Outlook's calendar-category palette — new categories pick from these
/// rather than a free-form color picker, keeping every category consistent
/// with the built-in ones (see `theme/app_category_colors.dart`).
///
/// Deliberately no longer starts with `AppColors.accent`: with the accent
/// now being Outlook blue, a pinned-accent entry would have duplicated the
/// blue below.
const categoryColorPalette = [
  Color(0xFF0078D4), // blue
  Color(0xFF107C10), // green
  Color(0xFFD83B01), // orange
  Color(0xFF5C2E91), // purple
  Color(0xFFD13438), // red
  Color(0xFF008272), // teal
  Color(0xFFC19C00), // gold
];
