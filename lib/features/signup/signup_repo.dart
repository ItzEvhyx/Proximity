import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/firebase/firebase_client.dart' as core;

/// Firebase Auth and Firestore access for sign-up. Each user owns one
/// `profiles/{uid}` document containing their account metadata and settings.
class SignUpRepo {
  SignUpRepo({FirebaseAuth? auth, FirebaseFirestore? database})
    : _auth = auth ?? core.firebaseAuth,
      _database = database ?? core.firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _database;

  /// Creates the Firebase Auth account and saves its non-secret profile data.
  Future<User> createAuthUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName('$firstName $lastName'.trim());
    await _database.collection('profiles').doc(user.uid).set({
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return user;
  }

  /// Firebase sends its own signed verification action link. No SMTP password
  /// or client-side verification secret is needed.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user');
    await user.sendEmailVerification();
  }

  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }
}
