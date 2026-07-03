import 'package:flutter/material.dart';

import '../../features/home/homescreen/home_screen.dart';
import '../../features/login/login_screen.dart';
import '../../features/mapbox_contribution/contribution_screen.dart';
import '../animations/screen_transitions.dart';
import '../session/user_session.dart';
import '../shared_prefs/shared_prefs.dart';

/// Central routing decisions, driven entirely by local state so they work
/// offline. All of these apply after the splash video.
///
/// Rules:
///  • Logged in            -> home screen (skip login and contribution).
///  • Logged out + new      -> login, then the contribution (welcome) screen
///                             once, then home.
///  • Logged out + returning-> login, then straight to home.
class AppRouter {
  const AppRouter._();

  /// The screen to show once the splash finishes (assuming connectivity).
  static Widget afterSplash() {
    return UserSession.instance.isLoggedIn
        ? const HomeScreen()
        : const LoginScreen();
  }

  /// [afterSplash] wrapped in the standard fade route.
  static Route<dynamic> afterSplashRoute() =>
      ScreenTransitions.fade(afterSplash());

  /// The route to push after a successful login/sign-up. A brand-new user
  /// (hasn't finished onboarding) sees the contribution screen once; everyone
  /// else goes straight to home.
  static Route<dynamic> afterLogin() {
    if (AppPrefs.hasCompletedOnboarding) {
      return ScreenTransitions.fade(const HomeScreen());
    }
    return ScreenTransitions.fade(const ContributionScreen());
  }

  /// The route to push once the contribution screen has done its thing.
  static Route<dynamic> afterContribution() {
    return ScreenTransitions.fade(const HomeScreen());
  }
}
