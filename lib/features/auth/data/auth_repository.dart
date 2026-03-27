import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/user_role.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (credential.user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: 'Авторизация не вернула пользователя.',
      );
    }
    return credential.user!;
  }

  Future<User> register({
    required String email,
    required String password,
    required UserRole role,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: 'Регистрация не вернула пользователя.',
      );
    }

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email.trim(),
      'name': name.trim(),
      'role': role.value,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return user;
  }

  Future<void> signOut() => _auth.signOut();

  Future<({UserRole role, String name})> fetchUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    final rawRole = data?['role'] as String?;
    final name = data?['name'] as String? ?? '';
    final role = rawRole != null ? UserRole.fromMap(rawRole) : UserRole.client;
    return (role: role, name: name);
  }
}
