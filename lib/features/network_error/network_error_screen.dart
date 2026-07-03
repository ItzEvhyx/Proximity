import 'package:flutter/material.dart';

import '../../core/network/network_service.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';

/// Shown after the splash when the device has no internet connection.
/// White background, illustration, message and a retry action.
class NetworkErrorScreen extends StatefulWidget {
  const NetworkErrorScreen({super.key});

  @override
  State<NetworkErrorScreen> createState() => _NetworkErrorScreenState();
}

class _NetworkErrorScreenState extends State<NetworkErrorScreen> {
  bool _checking = false;

  Future<void> _onTryAgain() async {
    setState(() => _checking = true);
    final online = await NetworkService.instance.hasConnection();
    if (!mounted) return;
    setState(() => _checking = false);

    if (online) {
      Navigator.of(context).pushReplacement(
        AppRouter.afterSplashRoute(),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Still no connection. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onOpenWifiSettings() {
    // TODO: open the device Wi-Fi settings (UI-only for now).
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'public/assets/images/no_network_img.png',
                  height: 210,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                const Text(
                  'No internet connection',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primary,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      height: 1.45,
                      color: AppColors.textGrey,
                    ),
                    children: [
                      TextSpan(
                        text: 'Proximity needs a connection to track your '
                            'route and wake you at the right stop. ',
                      ),
                      TextSpan(
                        text: 'Reconnect to keep sleeping easy.',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                _buildTryAgainButton(),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _onOpenWifiSettings,
                  child: const Text(
                    'Open Wi-Fi settings',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTryAgainButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _checking ? null : _onTryAgain,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          disabledForegroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _checking
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Try Again',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
