import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../maps_tab/pinned_trip.dart';

/// Past Trips tab content: vertical timeline with location cards seeded from
/// real [PinnedTrip] data coming from [MapsController.pinnedHistory].
class PastLocationsTab extends StatelessWidget {
  const PastLocationsTab({super.key, this.trips = const [], this.onTripTap});

  /// Real trip data from MapsController.
  final List<PinnedTrip> trips;

  /// Called when the user taps a trip card (opens re-pin modal).
  final ValueChanged<PinnedTrip>? onTripTap;

  @override
  Widget build(BuildContext context) {
    // Only show trips from the past 45 days.
    final cutoff = DateTime.now().subtract(const Duration(days: 45));
    final recentTrips = trips.where((t) => t.pinnedAt.isAfter(cutoff)).toList();

    if (recentTrips.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'No past trips yet.\nConfirm a location on the map to see it here.',
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
      padding: const EdgeInsets.only(left: 10, right: 0, top: 8, bottom: 100),
      itemCount: recentTrips.length,
      itemBuilder: (context, index) {
        final trip = recentTrips[index];
        final isFirst = index == 0;
        final isLast = index == recentTrips.length - 1;
        return _PastLocationRow(
          trip: trip,
          isFirst: isFirst,
          isLast: isLast,
          index: index + 1,
          onTap: onTripTap != null ? () => onTripTap!(trip) : null,
        );
      },
    );
  }
}

/// A single row in the past-trips timeline.
class _PastLocationRow extends StatelessWidget {
  const _PastLocationRow({
    required this.trip,
    required this.isFirst,
    required this.isLast,
    required this.index,
    this.onTap,
  });

  final PinnedTrip trip;
  final bool isFirst;
  final bool isLast;
  final int index;
  final VoidCallback? onTap;

  static const double _circleSize = 44;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Day + time label (centered vertically) ──
          SizedBox(
            width: 50,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dayLabel(trip.pinnedAt),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    trip.timeLabel,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Timeline column (circle centered, dashed lines above/below) ──
          SizedBox(
            width: _circleSize,
            child: Column(
              children: [
                Expanded(
                  child: _DashedVerticalLine(visible: !isFirst),
                ),
                // Circle node with date number (day of month)
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
                    '${trip.pinnedAt.day}',
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
          const SizedBox(width: 10),

          // ── Location card (clamped to right edge) ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: GestureDetector(
                onTap: onTap,
                child: _LocationCard(trip: trip),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Short day-of-week abbreviation from a DateTime.
  String _dayLabel(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }
}

/// Dashed vertical line. When [visible] is false, renders transparent
/// to maintain spacing.
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

/// Card displaying location name, time of arrival, and distance from real
/// [PinnedTrip] data.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.trip});

  final PinnedTrip trip;

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
          Text(
            trip.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                trip.timeLabel,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                trip.distanceLabel,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
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
