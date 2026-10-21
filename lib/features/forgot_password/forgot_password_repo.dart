import 'package:firebase_auth/firebase_auth.dart';

import '../../core/firebase/firebase_client.dart' as core;

/// Firebase Auth password recovery. Firebase emails a signed, expiring action
/// link and performs the password update on its own trusted backend.
class ForgotPasswordRepo {
  ForgotPasswordRepo({FirebaseAuth? auth}) : _auth = auth ?? core.firebaseAuth;
  final FirebaseAuth _auth;

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }
}
