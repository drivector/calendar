import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_settings.dart';
import 'firestore_providers.dart';

/// A single per-user doc, not a list-repository collection — there's only
/// ever one settings object per account, unlike goals/categories/blocks.
/// Exposed as a provider (not a private helper) so both [saveUserSettings]
/// and tests can write to it directly, the same way tests already write
/// through e.g. `plannedBlocksRepositoryProvider`.
final userSettingsDocProvider =
    Provider<DocumentReference<Map<String, dynamic>>>((ref) {
      final firestore = ref.watch(firestoreProvider);
      final uid = ref.watch(currentUidProvider);
      return firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('app');
    });

final userSettingsStreamProvider = StreamProvider<UserSettings>((ref) {
  return ref.watch(userSettingsDocProvider).snapshots().map((snapshot) {
    final data = snapshot.data();
    return data == null ? const UserSettings() : UserSettings.fromMap(data);
  });
});

/// The signed-in user's settings, live from Firestore — falls back to
/// [UserSettings]'s own defaults for an account that's never saved any
/// (the common case: nobody has touched this yet), and while the first
/// snapshot is still loading.
final userSettingsProvider = Provider<UserSettings>((ref) {
  return ref.watch(userSettingsStreamProvider).valueOrNull ??
      const UserSettings();
});

/// The actual save call, as an overridable provider rather than a bare
/// function reaching straight into [userSettingsDocProvider] — `cloud_
/// firestore`'s `DocumentReference` is a sealed class, so it can't be
/// wrapped or faked directly in a test the way this app's other repository
/// providers can be. Overriding this provider instead is how a test
/// exercises a real save *failure* (e.g. a permission-denied write) — see
/// the widget test covering exactly that.
final saveUserSettingsProvider =
    Provider<Future<void> Function(UserSettings)>((ref) {
      final doc = ref.watch(userSettingsDocProvider);
      return (settings) => doc.set(settings.toMap());
    });

Future<void> saveUserSettings(WidgetRef ref, UserSettings settings) {
  return ref.read(saveUserSettingsProvider)(settings);
}
