import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../../../core/global_services/cloudinary_services.dart';
import '../../../../../../../core/skeleton_loading/skeleton_loading.dart';
import '../../../../../../../core/theme/app_colors.dart';
import 'transit_categories.dart';
import 'view_table_screen.dart';

/// Green card showing the rail transit route map image + interchange info.
/// The route map image is fetched from Cloudinary. Tapping it opens a
/// full-screen pinch-zoom modal.
class TransitRouteMap extends StatelessWidget {
  const TransitRouteMap({super.key, required this.category});

  final FareCategory category;

  static final Color _gradientEnd =
      Color.lerp(AppColors.primary, Colors.black, 0.12)!;

  void _openMapModal(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (_) => _RouteMapModal(imageUrl: imageUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = CloudinaryService.instance.trainRoutesUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Route map card ────────────────────────────────────────────────
        DecoratedBox(
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
                // Header row: title + View Table button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ViewTableScreen(category: category),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'View Table',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Route map image from Cloudinary — tap to open full-screen
                GestureDetector(
                  onTap: () => _openMapModal(context, imageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      memCacheWidth: 600,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholder: (_, _) =>
                          const SkeletonBox(height: 200, borderRadius: 0),
                      errorWidget: (_, _, _) => Container(
                        height: 200,
                        color: AppColors.surfaceMuted,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: AppColors.hintGrey),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Interchange stations info ────────────────────────────────────
        const _InterchangeInfo(),
      ],
    );
  }
}

/// Shows interchange/transfer station connections between rail lines.
class _InterchangeInfo extends StatelessWidget {
  const _InterchangeInfo();

  static const _interchanges = [
    _Interchange(
      lineA: 'LRT-1',
      stationA: 'Doroteo Jose',
      lineB: 'LRT-2',
      stationB: 'Recto',
    ),
    _Interchange(
      lineA: 'LRT-1',
      stationA: 'EDSA',
      lineB: 'MRT-3',
      stationB: 'Taft Avenue',
    ),
    _Interchange(
      lineA: 'LRT-2',
      stationA: 'Araneta Center-Cubao',
      lineB: 'MRT-3',
      stationB: 'Araneta Center-Cubao',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Interchange Stations',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _interchanges.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _InterchangeRow(interchange: _interchanges[i]),
          ],
        ],
      ),
    );
  }
}

class _Interchange {
  final String lineA;
  final String stationA;
  final String lineB;
  final String stationB;

  const _Interchange({
    required this.lineA,
    required this.stationA,
    required this.lineB,
    required this.stationB,
  });
}

class _InterchangeRow extends StatelessWidget {
  const _InterchangeRow({required this.interchange});

  final _Interchange interchange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LineBadge(label: interchange.lineA),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            interchange.stationA,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.sync_alt_rounded, size: 16, color: AppColors.primary),
        ),
        _LineBadge(label: interchange.lineB),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            interchange.stationB,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _LineBadge extends StatelessWidget {
  const _LineBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: 10,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Full-screen modal showing the route map with pinch-to-zoom.
class _RouteMapModal extends StatelessWidget {
  const _RouteMapModal({required this.imageUrl});

  final String imageUrl;

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
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, _) => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              errorWidget: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.hintGrey, size: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
