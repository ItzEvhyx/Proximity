# Firebase setup

The app is configured for Firebase Authentication and Cloud Firestore project
`proximity-4fb3d` on Android.

## One-time local configuration

1. Install the FlutterFire CLI if it is not already installed:

   ```bash
   dart pub global activate flutterfire_cli
   ```

2. To add another platform later, run from the repository root:

   ```bash
   flutterfire configure --platforms=android,ios,web,macos,windows
   ```

   Select `proximity-4fb3d` and register only the platforms you ship. This
   updates `lib/firebase_options.dart` and the native Firebase configuration.

3. Install the Firebase CLI, log in, then deploy the checked-in rules:

   ```bash
   npm install -g firebase-tools
   firebase login
   firebase init firestore
   firebase deploy --only firestore:rules
   ```

   When prompted by `firebase init firestore`, use the existing
   `firestore.rules` file and select the same project configured above.

## Firebase Console checklist

1. Keep `android/app/google-services.json` in the repository. FlutterFire has
   already placed the downloaded Android configuration file there. It is not a
   server secret, and the duplicate in Downloads is not used by the app.
2. In **Build → Authentication → Sign-in method**, enable **Email/Password**
   and **Google**. Add the Google-support email and configure the OAuth consent
   screen in Google Cloud if prompted.
3. For Android Google login, add the SHA-1 and SHA-256 fingerprints for both
   debug and release signing keys in **Project settings → Your apps**. Download
   the refreshed `google-services.json`, or run `flutterfire configure` again.
4. In **Build → Firestore Database**, create a production-mode database in a
   suitable region. The checked-in `firestore.rules` have been deployed.
5. In **Authentication → Settings → Authorized domains**, add every production
   web domain that will handle Firebase email verification and password-reset
   links. Customize email templates under **Authentication → Templates**.
6. Create test users afresh. Supabase password hashes and user IDs cannot be
   imported directly into Firebase Authentication. Export any profile/settings
   data you need from Supabase and write it as `profiles/{firebaseAuthUid}`
   documents after each user has registered in Firebase.

## Data model

`profiles/{uid}` keeps the same application field names as before:
`first_name`, `last_name`, `email`, `avatar_url`, `alarm_sound`,
`alert_zone_distances`, `alert_zone_unit`, `dismiss_method`, and
`vibration_intensity`. `uid` is always the Firebase Authentication UID.

## Authentication behavior

Email sign-up now sends Firebase's signed verification link (not a client-side
OTP). Password recovery also uses Firebase's signed reset link. This removes
the old client-bundled SMTP credential and Supabase Edge Function dependency.
