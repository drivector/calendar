import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// The signed-in user's uid — every per-user repository below is only ever
/// watched from inside [RootShell]'s subtree, which [AuthGate] only mounts
/// once a user is signed in, so a null uid here would mean this was watched
/// somewhere it shouldn't have been.
final currentUidProvider = Provider<String>((ref) {
  return ref.watch(authStateChangesProvider).requireValue!.uid;
});
