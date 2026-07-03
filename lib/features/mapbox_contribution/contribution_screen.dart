import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/shared_prefs/shared_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/diamond_loader.dart';

/// Shown once to a brand-new user right after their first login while the map
/// loads. Solid brand-green background with the Mapbox attribution, logo, and
/// loading spinner. After a short delay it marks onboarding complete and moves
/// on to the home screen (so it never shows again).
class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key});

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), _goHome);
  }

  Future<void> _goHome() async {
    await AppPrefs.setOnboardingComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(AppRouter.afterContribution());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(color: AppColors.primary),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Made possible with:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Image.asset(
                    'public/assets/icons/mapbox_logo.png',
                    height: 58,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sit tight while we load the Map for you...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.white,
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 44),
                  const DiamondLoader(color: AppColors.white, size: 88),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}