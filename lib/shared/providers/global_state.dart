import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/user_role.dart';

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final demoRoleProvider = StateProvider<UserRole?>((ref) => null);

final currentUserProvider = StreamProvider<AppUser?>((ref) async* {
  final demoRole = ref.watch(demoRoleProvider);

  if (demoRole != null) {
    yield AppUser(
      uid: 'demo-${demoRole.name}',
      email: '${demoRole.name}@avishu.demo',
      role: demoRole,
    );
    return;
  }

  await for (final user in FirebaseAuth.instance.authStateChanges()) {
    if (user == null) {
      yield null;
      continue;
    }

    var role = UserRole.client;

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final rawRole = userSnapshot.data()?['role'] as String?;
      if (rawRole != null) {
        role = UserRole.fromMap(rawRole);
      }
    } catch (_) {
      role = UserRole.client;
    }

    yield AppUser(uid: user.uid, email: user.email ?? '', role: role);
  }
});
