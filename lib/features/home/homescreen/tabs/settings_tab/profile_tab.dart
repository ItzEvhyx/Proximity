import 'package:flutter/material.dart';

import '../../../../../core/animations/screen_transitions.dart';
import '../../../../../core/session/user_session.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../login/login_screen.dart';
import 'settings_screen.dart';

/// Profile tab — shows the Settings screen with a logout button at the bottom.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

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
    return Stack(
      children: [
        const SettingsScreen(),
        // Floating logout button at the bottom
        Positioned(
          left: 20,
          right: 20,
          bottom: 24,
          child: SafeArea(
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => _logout(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  backgroundColor: AppColors.white,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'Log out',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
