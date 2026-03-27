import 'user_role.dart';

class AppUser {
  final String uid;
  final String email;
  final UserRole role;

  AppUser({required this.uid, required this.email, required this.role});
}
