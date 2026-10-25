import 'package:flutter/material.dart';

import '../../../../../core/animations/screen_transitions.dart';
import '../../../../../core/session/user_session.dart';
import '../../../../login/login_screen.dart';
import 'settings_screen.dart';

/// Profile tab — shows the scrollable Settings screen and handles logout.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, this.active = false});

  final bool active;

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await UserSession.instance.onLogout();
    navigator.pushAndRemoveUntil(
      ScreenTransitions.fade(const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(active: active, onLogout: () => _logout(context));
  }
}
