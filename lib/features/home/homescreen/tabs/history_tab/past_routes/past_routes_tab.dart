import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import 'saved_route.dart';

/// Past Routes tab content: vertical timeline with route cards seeded from
/// real [SavedRoute] data persisted by [RouteHistoryService].
class PastRoutesTab extends StatelessWidget {
  const PastRoutesTab({super.key, this.routes = const [], this.onRouteTap});

  /// Real route history from RouteHistoryService.
  final List<SavedRoute> routes;

  /// Called when the user taps a route card (opens Transit Route modal).
  final ValueChanged<SavedRoute>? onRouteTap;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'No past routes yet.\nSearch for a route in Way Finder to see it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textGrey,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 14, right: 0, top: 8, bottom: 100),
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];
        final isFirst = index == 0;
        final isLast = index == routes.length - 1;
        return _PastRouteRow(
          route: route,
          isFirst: isFirst,
          isLast: isLast,
          onTap: onRouteTap != null ? () => onRouteTap!(route) : null,
        );
      },
    );
  }
}

/// A single row in the past-routes timeline.
class _PastRouteRow extends StatelessWidget {
  const _PastRouteRow({
    required this.route,
    required this.isFirst,
    required this.isLast,
    this.onTap,
  });

  final SavedRoute route;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  static const double _circleSize = 44;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline column (circle centered, dashed lines above/below) ──
          SizedBox(
            width: _circleSize,
            child: Column(
              children: [
                Expanded(
                  child: _DashedVerticalLine(visible: !isFirst),
                ),
                // Circle node with date number
                Container(
                  width: _circleSize,
                  height: _circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white,
                    border: Border.all(color: AppColors.primary, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${route.searchedAt.day}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Expanded(
                  child: _DashedVerticalLine(visible: !isLast),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Route card ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: GestureDetector(
                onTap: onTap,
                child: _RouteCard(route: route),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed vertical line.
class _DashedVerticalLine extends StatelessWidget {
  const _DashedVerticalLine({this.visible = true});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.expand();
    return SizedBox.expand(
      child: CustomPaint(painter: _DashedVerticalPainter()),
    );
  }
}

class _DashedVerticalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const dashHeight = 6.0;
    const dashSpace = 5.0;
    double y = 0;
    final x = size.width / 2;

    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, y + dashHeight), paint);
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Card displaying route info with truncated origin → destination,
/// date, time estimate, and distance.
class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route});

  final SavedRoute route;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          bottomLeft: Radius.circular(14),
        ),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Starting location → Destination row ──
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: Color(0xFFE53935),
                size: 18,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  route.originTruncated,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.textDark,
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  route.destinationTruncated,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const Icon(
                Icons.location_on,
                color: AppColors.primary,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ── Dashed divider ──
          _DashedHorizontalDivider(),
          const SizedBox(height: 6),

          // ── Date row ──
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.textDark,
                size: 12,
              ),
              const SizedBox(width: 5),
              Text(
                route.dateLabel,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              const Icon(Icons.access_time_rounded,
                  size: 10, color: AppColors.textGrey),
              const SizedBox(width: 3),
              Text(
                route.totalEta,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '·',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.location_on_rounded,
                  size: 10, color: AppColors.primary),
              const SizedBox(width: 3),
              Text(
                route.totalDistance,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painted dashed horizontal divider line in green.
class _DashedHorizontalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 1,
      child: CustomPaint(painter: _DashedHorizontalPainter()),
    );
  }
}

class _DashedHorizontalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
