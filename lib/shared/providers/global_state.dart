import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/user_role.dart';
import '../../features/users/domain/models/user_profile.dart';

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = StreamProvider<AppUser?>((ref) async* {
  await for (final user in FirebaseAuth.instance.authStateChanges()) {
    if (user == null) {
      yield null;
      continue;
    }

    var role = UserRole.client;
    var name = '';

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userSnapshot.exists) {
        final profile = UserProfile.fromFirestore(userSnapshot);
        role = profile.role;
        name = profile.fullName;
      }
    } catch (_) {
      role = UserRole.client;
    }

    yield AppUser(
      uid: user.uid,
      email: user.email ?? '',
      role: role,
      name: name,
    );
  }
});
