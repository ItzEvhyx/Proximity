import '../shared_prefs/shared_prefs.dart';
import '../firebase/firebase_client.dart';

/// Owns the logged-in user's identity for the app.
///
/// The user id is persisted locally (via [AppPrefs]) so the app knows who is
/// logged in offline and never logs the user out just because they reopened
/// the app. Each user has a distinct id, so logging a different user in simply
/// replaces the stored id — sessions never bleed into each other.
class UserSession {
  UserSession._();

  static final UserSession instance = UserSession._();

  /// The current user's id, or null when logged out.
  String? get userId => AppPrefs.loggedInUserId;

  bool get isLoggedIn => userId != null;

  /// Reconciles local state with any Firebase session restored at start-up.
  /// If Firebase already has a session (e.g. from a previous run) but we have
  /// no stored id yet, adopt it so routing treats the user as logged in.
  Future<void> restore() async {
    final user = firebaseAuth.currentUser;
    if (user != null && AppPrefs.loggedInUserId == null) {
      await AppPrefs.setLoggedInUserId(user.uid);
    }
  }

  /// Records a successful login. Call with the authenticated user's id.
  Future<void> onLogin(String userId) => AppPrefs.setLoggedInUserId(userId);

  /// Signs the user out of Firebase and clears the local session id.
  Future<void> onLogout() async {
    await firebaseAuth.signOut();
    await AppPrefs.clearLoggedInUserId();
  }
}
