import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';

/// Green card showing the rail transit route map image.
/// Only visible for rail categories (LRT-1, LRT-2, MRT) — other transport
/// modes added later will not show this card.
///
/// Tapping the route map image opens a full-screen modal with the image
/// scaled up and pinch-zoomable. Tapping outside (the scrim) closes it.
class TransitRouteMap extends StatelessWidget {
  const TransitRouteMap({super.key});

  static final Color _gradientEnd =
      Color.lerp(AppColors.primary, Colors.black, 0.12)!;

  void _openMapModal(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (_) => const _RouteMapModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary, _gradientEnd],
        ),
        border: Border.all(color: const Color(0x10000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(4, 4),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: title + train illustration (bottom-aligned)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Rail Transits',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppColors.white,
                  ),
                ),
                const Spacer(),
                Image.asset(
                  'public/assets/images/long_train_img.png',
                  height: 18,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Route map image — tap to open full-screen modal
            GestureDetector(
              onTap: () => _openMapModal(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'public/assets/images/train_routes_img.png',
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen modal that shows the route map scaled up with pinch-to-zoom.
/// Tap outside the image (the dark scrim) to dismiss.
class _RouteMapModal extends StatelessWidget {
  const _RouteMapModal();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 80),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: AppColors.white,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: Image.asset(
              'public/assets/images/train_routes_img.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
