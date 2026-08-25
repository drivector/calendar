import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar_tracker/state/auth_providers.dart';
import 'package:calendar_tracker/state/day_view_providers.dart';
import 'package:calendar_tracker/state/firestore_providers.dart';
import 'package:calendar_tracker/state/goals_providers.dart';

import '../support/firestore_test_fixtures.dart';

Future<ProviderContainer> _signedInContainer() async {
  const uid = 'test-uid';
  final firestore = await seededFirestore(uid);
  final container = ProviderContainer(
    overrides: [
      firebaseAuthProvider.overrideWithValue(
        MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
      ),
      firestoreProvider.overrideWithValue(firestore),
    ],
  );
  await container.read(authStateChangesProvider.future);
  await container.read(allPlannedBlocksStreamProvider.future);
  await container.read(allTrackedBlocksStreamProvider.future);
  await container.read(goalsStreamProvider.future);
  return container;
}

void main() {
  group('visibleDayBlocksProvider', () {
    test(
      'in Day mode, matches dayViewPlannedBlocksProvider/trackedBlocksProvider '
      'for the selected date',
      () async {
        final container = await _signedInContainer();
        addTearDown(container.dispose);
        container.read(selectedDateProvider.notifier).state = DateTime(
          2026,
          8,
          20,
        );

        expect(container.read(dayViewModeProvider), DayViewMode.day);
        final dayBlocks = container.read(visibleDayBlocksProvider);
        expect(dayBlocks, hasLength(1));
        expect(dayBlocks.single.date, DateTime(2026, 8, 20));

        final expectedPlanned = container.read(dayViewPlannedBlocksProvider);
        final expectedTracked = container.read(trackedBlocksProvider);

        expect(
          dayBlocks.single.planned.map((b) => b.id).toSet(),
          expectedPlanned.map((b) => b.id).toSet(),
        );
        expect(
          dayBlocks.single.tracked.map((b) => b.id).toSet(),
          expectedTracked.map((b) => b.id).toSet(),
        );
      },
    );
  });
}
