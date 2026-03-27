import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/user_role.dart';

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final user = await ref.watch(authStateChangesProvider.future);
  if (user == null) return null;
  
  // Here we would normally fetch the user document from Firestore to get the role.
  // For the architecture template, we return a mock AppUser with a Client role by default.
  // We can change this manually during testing to see different dashboards.
  return AppUser(uid: user.uid, email: user.email ?? '', role: UserRole.production);
});
