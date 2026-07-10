import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';

/// Dummy data model for a past location entry.
class _PastLocationEntry {
  const _PastLocationEntry({
    required this.day,
    required this.time,
    required this.routeNumber,
    required this.locationName,
    required this.timeOfArrival,
    required this.distance,
  });

  final String day;
  final String time;
  final String routeNumber;
  final String locationName;
  final String timeOfArrival;
  final String distance;
}

/// Dummy data for past locations.
const _dummyLocations = [
  _PastLocationEntry(
    day: 'Mon',
    time: '7:00 PM',
    routeNumber: '21',
    locationName: 'Location Name',
    timeOfArrival: 'Time of Arrival',
    distance: 'Distance',
  ),
  _PastLocationEntry(
    day: 'Sun',
    time: '7:00 PM',
    routeNumber: '21',
    locationName: 'Location Name',
    timeOfArrival: 'Time of Arrival',
    distance: 'Distance',
  ),
  _PastLocationEntry(
    day: 'Thu',
    time: '7:00 PM',
    routeNumber: '21',
    locationName: 'Location Name',
    timeOfArrival: 'Time of Arrival',
    distance: 'Distance',
  ),
  _PastLocationEntry(
    day: 'Wed',
    time: '7:00 PM',
    routeNumber: '21',
    locationName: 'Location Name',
    timeOfArrival: 'Time of Arrival',
    distance: 'Distance',
  ),
  _PastLocationEntry(
    day: 'Tue',
    time: '7:00 PM',
    routeNumber: '21',
    locationName: 'Location Name',
    timeOfArrival: 'Time of Arrival',
    distance: 'Distance',
  ),
  _PastLocationEntry(
    day: 'Sat',
    time: '7:00 PM',
    routeNumber: '21',
    locationName: 'Location Name',
    timeOfArrival: 'Time of Arrival',
    distance: 'Distance',
  ),
];

/// Past Locations tab content: vertical timeline with location cards.
class PastLocationsTab extends StatelessWidget {
  const PastLocationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 10, right: 0, top: 8, bottom: 100),
      itemCount: _dummyLocations.length,
      itemBuilder: (context, index) {
        final entry = _dummyLocations[index];
        final isLast = index == _dummyLocations.length - 1;
        return _PastLocationRow(entry: entry, isLast: isLast);
      },
    );
  }
}

/// A single row in the past-locations timeline. Uses IntrinsicHeight so the
/// timeline column stretches to the card height, with the circle centered.
class _PastLocationRow extends StatelessWidget {
  const _PastLocationRow({required this.entry, required this.isLast});

  final _PastLocationEntry entry;
  final bool isLast;

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
                    entry.day,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    entry.time,
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
                // Dashed line above circle (connects from previous node)
                if (true)
                  Expanded(
                    child: _DashedVerticalLine(
                      visible: entry != _dummyLocations.first,
                    ),
                  ),
                // Circle node
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
                    entry.routeNumber,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                // Dashed line below circle (connects to next node)
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
              child: _LocationCard(entry: entry),
            ),
          ),
        ],
      ),
    );
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

/// Card displaying location name, time of arrival, and distance.
/// Rounded on the left, flat on the right (clamped to screen edge).
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.entry});

  final _PastLocationEntry entry;

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
            entry.locationName,
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
              Icon(Icons.access_time_rounded, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                entry.timeOfArrival,
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
              Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                entry.distance,
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
