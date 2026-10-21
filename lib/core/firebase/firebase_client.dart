import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// Initializes the Firebase SDK once during application startup.
///
/// Platform configuration is supplied by `flutterfire configure` (see
/// `docs/FIREBASE_SETUP.md`). Keeping this in one place prevents Firebase
/// initialization from leaking into feature code.
Future<void> initFirebase() =>
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

FirebaseAuth get firebaseAuth => FirebaseAuth.instance;
FirebaseFirestore get firestore => FirebaseFirestore.instance;

CollectionReference<Map<String, dynamic>> get profiles =>
    firestore.collection('profiles');

/// Merges fields into the signed-in user's profile document. Firestore rules
/// restrict this document to its owner; the client never chooses another uid.
Future<void> updateCurrentProfile(Map<String, dynamic> fields) async {
  final uid = firebaseAuth.currentUser?.uid;
  if (uid == null) return;

  await profiles.doc(uid).set({
    ...fields,
    'updated_at': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
