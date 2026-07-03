import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Live password-rule checklist that lights each rule green with a check as it
/// is satisfied (red outlined circle while unmet). Computes the rules from the
/// [password] string so both the sign-up and reset-password cards can share it.
class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({super.key, required this.password});

  final String password;

  bool get _hasLength => password.length >= 8 && password.length <= 25;
  bool get _hasSpecial => password.contains(RegExp(r'[^A-Za-z0-9\s]'));
  bool get _hasNumber => password.contains(RegExp(r'[0-9]'));
  bool get _hasUppercase => password.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => password.contains(RegExp(r'[a-z]'));
  bool get _hasNoSpaces =>
      password.isNotEmpty && !password.contains(RegExp(r'\s'));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          _Req(label: '8 characters minimum, 25 maximum', met: _hasLength),
          const SizedBox(height: 6),
          _Req(label: 'At least one special character', met: _hasSpecial),
          const SizedBox(height: 6),
          _Req(label: 'At least one number', met: _hasNumber),
          const SizedBox(height: 6),
          _Req(label: 'At least one uppercase letter', met: _hasUppercase),
          const SizedBox(height: 6),
          _Req(label: 'At least one lowercase letter', met: _hasLowercase),
          const SizedBox(height: 6),
          _Req(label: 'No spaces allowed', met: _hasNoSpaces),
        ],
      ),
    );
  }
}

class _Req extends StatelessWidget {
  const _Req({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? AppColors.primary : Colors.redAccent;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: color,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: met
              ? const Icon(
                  Icons.check_circle_rounded,
                  key: ValueKey('met'),
                  color: AppColors.primary,
                  size: 18,
                )
              : const Icon(
                  Icons.circle_outlined,
                  key: ValueKey('unmet'),
                  color: Colors.redAccent,
                  size: 18,
                ),
        ),
      ],
    );
  }
}
