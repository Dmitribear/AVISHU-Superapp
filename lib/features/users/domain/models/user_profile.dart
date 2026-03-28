import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../features/auth/domain/user_role.dart';
import '../../../../shared/utils/firestore_parsing.dart';

class UserProfile {
  final String id;
  final UserRole role;
  final String fullName;
  final String phone;
  final String email;
  final String avatarUrl;
  final String city;
  final int loyaltyPoints;
  final double loyaltyTotalSpent;
  final double loyaltyBonusBalance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.role,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.avatarUrl,
    required this.city,
    required this.loyaltyPoints,
    required this.loyaltyTotalSpent,
    required this.loyaltyBonusBalance,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAt =
        dateTimeFromFirestoreValue(data['createdAt']) ?? DateTime.now();
    final updatedAt =
        dateTimeFromFirestoreValue(data['updatedAt']) ?? createdAt;

    return UserProfile(
      id: stringFromFirestoreValue(data['id'], fallback: doc.id),
      role: UserRole.fromMap(
        stringFromFirestoreValue(data['role'], fallback: 'client'),
      ),
      fullName: stringFromFirestoreValue(
        data['fullName'],
        fallback: stringFromFirestoreValue(data['name']),
      ),
      phone: stringFromFirestoreValue(data['phone']),
      email: stringFromFirestoreValue(data['email']),
      avatarUrl: stringFromFirestoreValue(data['avatarUrl']),
      city: stringFromFirestoreValue(data['city']),
      loyaltyPoints: intFromFirestoreValue(data['loyaltyPoints']),
      loyaltyTotalSpent: doubleFromFirestoreValue(data['loyaltyTotalSpent']),
      loyaltyBonusBalance: doubleFromFirestoreValue(
        data['loyaltyBonusBalance'],
        fallback: intFromFirestoreValue(data['loyaltyPoints']).toDouble(),
      ),
      isActive: boolFromFirestoreValue(data['isActive'], fallback: true),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role.value,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'avatarUrl': avatarUrl,
      'city': city,
      'loyaltyPoints': loyaltyPoints,
      'loyaltyTotalSpent': loyaltyTotalSpent,
      'loyaltyBonusBalance': loyaltyBonusBalance,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      // Legacy compatibility for existing UI code.
      'uid': id,
      'name': fullName,
    };
  }
}
