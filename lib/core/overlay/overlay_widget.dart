import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// A compact floating card displayed over other apps, showing real-time
/// ETA and Distance — similar to Google Maps' mini navigation bubble.
///
/// Receives data updates from the main app via [FlutterOverlayWindow.overlayListener].
class ProximityOverlayCard extends StatefulWidget {
  const ProximityOverlayCard({super.key});

  @override
  State<ProximityOverlayCard> createState() => _ProximityOverlayCardState();
}

class _ProximityOverlayCardState extends State<ProximityOverlayCard> {
  String _eta = '--';
  String _distance = '--';
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    // Listen for data shared from the main app.
    _sub = FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is String && data.contains('|')) {
        // Expected format: "eta|distance" e.g. "4 min|350 m"
        final parts = data.split('|');
        if (parts.length == 2 && mounted) {
          setState(() {
            _eta = parts[0];
            _distance = parts[1];
          });
        }
      }
    });

    // Tell the main app we're ready to receive data.
    // The main app listens for 'overlay_ready' and re-sends current values.
    FlutterOverlayWindow.shareData('overlay_ready');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          // Tapping the overlay brings the user back to the app.
          FlutterOverlayWindow.shareData('open_app');
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Proximity logo / icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF019D43).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.near_me_rounded,
                    color: Color(0xFF019D43),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // ETA pill
              _DataPill(
                icon: Icons.schedule_rounded,
                label: 'ETA',
                value: _eta,
                color: const Color(0xFF019D43),
              ),
              const SizedBox(width: 12),
              // Distance pill
              _DataPill(
                icon: Icons.straighten_rounded,
                label: 'Dist',
                value: _distance,
                color: const Color(0xFF2196F3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small pill showing an icon + label + value for the overlay card.
class _DataPill extends StatelessWidget {
  const _DataPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
