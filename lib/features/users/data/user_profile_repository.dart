import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/domain/user_role.dart';
import '../domain/models/user_profile.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepository(),
);

final allUserProfilesProvider = StreamProvider<Map<String, UserProfile>>((ref) {
  return ref.watch(userProfileRepositoryProvider).watchAll();
});

class UserProfileRepository {
  final FirebaseFirestore _firestore;

  UserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<UserProfile?> fetchById(String userId) async {
    final doc = await _users.doc(userId).get();
    if (!doc.exists) {
      return null;
    }
    return UserProfile.fromFirestore(doc);
  }

  Stream<UserProfile?> watchById(String userId) {
    return _users.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return UserProfile.fromFirestore(snapshot);
    });
  }

  Stream<Map<String, UserProfile>> watchAll() {
    return _users.snapshots().map((snapshot) {
      final profiles = <String, UserProfile>{};
      for (final doc in snapshot.docs) {
        final profile = UserProfile.fromFirestore(doc);
        profiles[profile.id] = profile;
      }
      return profiles;
    });
  }

  Future<UserProfile> upsertProfile({
    required String userId,
    required UserRole role,
    required String fullName,
    required String email,
    String phone = '',
    String avatarUrl = '',
    String city = '',
    int loyaltyPoints = 0,
    double loyaltyTotalSpent = 0,
    double loyaltyBonusBalance = 0,
    bool isActive = true,
  }) async {
    final existing = await fetchById(userId);
    final now = DateTime.now();
    final profile = UserProfile(
      id: userId,
      role: role,
      fullName: fullName,
      phone: phone,
      email: email,
      avatarUrl: avatarUrl,
      city: city,
      loyaltyPoints: loyaltyPoints,
      loyaltyTotalSpent: loyaltyTotalSpent,
      loyaltyBonusBalance: loyaltyBonusBalance,
      isActive: isActive,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await _users.doc(userId).set(profile.toMap(), SetOptions(merge: true));
    return profile;
  }
}
