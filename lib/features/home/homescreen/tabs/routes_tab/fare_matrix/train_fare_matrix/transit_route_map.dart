import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_colors.dart';
import 'transit_categories.dart';
import 'view_table_screen.dart';

/// Dark card showing the bundled rail transit route map + interchange info.
/// Tapping it opens a full-screen pinch-zoom modal.
class TransitRouteMap extends StatelessWidget {
  const TransitRouteMap({super.key, required this.category});

  final FareCategory category;
  static const _mapAsset = 'public/assets/images/train_maps.png';

  void _openMapModal(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (_) => const _RouteMapModal(assetPath: _mapAsset),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Route map card ────────────────────────────────────────────────
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: AppColors.surfaceGradient,
            border: Border.all(color: AppColors.border),
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
                            builder: (_) => ViewTableScreen(category: category),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
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
                // Bundled route map — tap to open full-screen.
                GestureDetector(
                  onTap: () => _openMapModal(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      _mapAsset,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
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
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
              Icon(
                Icons.swap_horiz_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
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
          child: Icon(
            Icons.sync_alt_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
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
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: 10,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Full-screen modal showing the route map with pinch-to-zoom.
class _RouteMapModal extends StatelessWidget {
  const _RouteMapModal({required this.assetPath});

  final String assetPath;

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
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
