import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/firebase/firebase_client.dart' as core;

/// Firebase Auth access for email/password and Google login.
class LoginRepo {
  LoginRepo({
    FirebaseAuth? auth,
    FirebaseFirestore? database,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? core.firebaseAuth,
       _database = database ?? core.firestore,
       _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final FirebaseFirestore _database;
  final GoogleSignIn _googleSignIn;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<bool> isCurrentEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Returns null when the account picker is cancelled.
  Future<UserCredential?> signInWithGoogle() async {
    await _googleSignIn.signOut();
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Ensures users created by Google sign-in have the same profile document as
  /// email/password users. The document is owned by the authenticated user,
  /// which matches the Firestore rules.
  Future<void> ensureGoogleProfile(User user) {
    final nameParts = (user.displayName ?? '').trim().split(RegExp(r'\s+'));
    final firstName = nameParts.isEmpty || nameParts.first.isEmpty
        ? ''
        : nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';

    return _database.collection('profiles').doc(user.uid).set({
      'first_name': firstName,
      'last_name': lastName,
      'email': user.email ?? '',
      'avatar_url': user.photoURL,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
