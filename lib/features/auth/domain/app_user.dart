import 'user_role.dart';

class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.name = '',
  });

  String get displayName => name.isNotEmpty ? name : email.split('@').first;
}
