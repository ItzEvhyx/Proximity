import 'package:flutter/material.dart';

import '../../../../core/animations/screen_transitions.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/work_in_progress.dart';
import '../../../login/login_screen.dart';

/// Profile tab (not built yet) — also hosts the logout button.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    // Signs out of Supabase and clears the locally stored session id.
    await UserSession.instance.onLogout();
    navigator.pushAndRemoveUntil(
      ScreenTransitions.fade(const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WorkInProgressView(
      child: OutlinedButton.icon(
        onPressed: () => _logout(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    );
  }
}
