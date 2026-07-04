import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../homescreen_map_renderer.dart';
import 'maps_controller.dart';

/// Maps tab: the interactive Philippines map with a floating search bar and a
/// draggable info card sitting on top of it (behind the navbar).
class MapsTab extends StatelessWidget {
  const MapsTab({super.key, this.onMapReady, this.controller});

  /// Forwarded to the map so the shell knows when the map is ready to show.
  final VoidCallback? onMapReady;

  /// Shared maps state (search + selection). Drives the info/confirm card.
  final MapsController? controller;

  @override
  Widget build(BuildContext context) {
    // Note: the floating search bar is rendered once by HomeScreen (shared by
    // the Maps and Routes tabs), so it is intentionally not duplicated here.
    return Stack(
      children: [
        Positioned.fill(
          child: HomescreenMapRenderer(
            onReady: onMapReady,
            controller: controller,
          ),
        ),
        // The bottom card either shows past trips or, once a location is
        // pinned, a "Confirm Location" pill.
        Positioned.fill(child: _BottomCard(controller: controller)),
      ],
    );
  }
}

/// Switches between the draggable "Past trips" sheet and the "Confirm Location"
/// card based on whether a searched location is currently pinned.
class _BottomCard extends StatelessWidget {
  const _BottomCard({this.controller});

  final MapsController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return _DraggableInfoCard();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.hasPin) {
          return _ConfirmLocationCard(
            title: controller.pinned!.name,
            subtitle: controller.pinned!.address ??
                controller.pinned!.categoryLabel,
            locked: controller.locked,
            resolving: controller.resolvingPin,
            onConfirm: controller.confirmPin,
            onCancel: controller.clearPin,
            onEdit: controller.unlockPin,
          );
        }
        return _DraggableInfoCard();
      },
    );
  }
}

/// Bottom card shown when a location is pinned: the selected place with a
/// full-width green "Confirm Location" pill. Sits just above the navbar.
class _ConfirmLocationCard extends StatelessWidget {
  const _ConfirmLocationCard({
    required this.title,
    required this.subtitle,
    required this.locked,
    required this.resolving,
    required this.onConfirm,
    required this.onCancel,
    required this.onEdit,
  });

  final String title;
  final String subtitle;
  final bool locked;
  final bool resolving;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          // Clear the floating navbar that sits at the very bottom.
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            resolving ? 'Locating nearest place…' : subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.textGrey,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onCancel,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.textGrey,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      locked
                          ? Icons.lock_rounded
                          : Icons.open_with_rounded,
                      size: 14,
                      color: AppColors.textGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        locked
                            ? 'Location locked. Tap edit to adjust.'
                            : 'Drag the pin to fine-tune the exact spot.',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.textGrey,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ConfirmButton(
                  locked: locked,
                  onConfirm: onConfirm,
                  onEdit: onEdit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width pill that confirms the pinned location, then flips to a locked
/// "confirmed" state with an option to edit (re-enable dragging).
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.locked,
    required this.onConfirm,
    required this.onEdit,
  });

  final bool locked;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (!locked) {
      return Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onConfirm,
          borderRadius: BorderRadius.circular(30),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Center(
              child: Text(
                'Confirm Location',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Locked state: confirmed badge + edit action.
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Location Confirmed',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(30),
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single past trip the user has taken. Placeholder model until real trip
/// history is wired in.
class _PastTrip {
  const _PastTrip({
    required this.locationName,
    required this.date,
    required this.time,
    required this.distance,
    required this.startingLocation,
  });

  final String locationName;
  final String date;
  final String time;
  final String distance;
  final String startingLocation;
}

/// White card that floats over the map. Starts at 30% of the screen height and
/// can be dragged taller or shorter. Shows the user's past trips.
class _DraggableInfoCard extends StatelessWidget {
  // Placeholder trips until history is fed in from the backend.
  static const List<_PastTrip> _trips = [
    _PastTrip(
      locationName: 'Arthaland Pacific Tower',
      date: '-',
      time: '-',
      distance: '-',
      startingLocation: '-',
    ),
    _PastTrip(
      locationName: 'ALTO Coffee Group',
      date: '-',
      time: '-',
      distance: '-',
      startingLocation: '-',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.15,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 16,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Header row: "Past trips" on the left, bus icon on the right.
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Past trips',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Image.asset(
                          'public/assets/icons/bus_icon.png',
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(
                      color: AppColors.textGrey,
                      thickness: 1,
                      height: 1,
                    ),
                    // Trip rows, each followed by a divider.
                    for (final trip in _trips) ...[
                      _TripRow(trip: trip),
                      const Divider(
                        color: AppColors.textGrey,
                        thickness: 1,
                        height: 1,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One past-trip entry: the location header with its details on the left and a
/// "Reverse Trip" button on the right.
class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip});

  final _PastTrip trip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                _DetailLine(label: 'Date of Trip', value: trip.date),
                _DetailLine(label: 'Time of Trip', value: trip.time),
                _DetailLine(label: 'Distance covered', value: trip.distance),
                _DetailLine(
                  label: 'Starting Location',
                  value: trip.startingLocation,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ReverseTripButton(
            onTap: () {
              // TODO: wire up trip reversal once routing is implemented.
            },
          ),
        ],
      ),
    );
  }
}

/// A single "Label ○ value" detail line inside a trip row. The circle acts as
/// a divider between the label and its value.
class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: _CircleDivider(),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textGrey,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small hollow circle used to separate a detail label from its value.
class _CircleDivider extends StatelessWidget {
  const _CircleDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textGrey, width: 1),
      ),
    );
  }
}

/// Green pill button that reverses a past trip, showing the revert icon.
class _ReverseTripButton extends StatelessWidget {
  const _ReverseTripButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(   
                'Reverse Trip',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              Image.asset(
                'public/assets/icons/revert_icon.png',
                width: 15,
                height: 15,
                fit: BoxFit.contain,
                color: AppColors.white,
                colorBlendMode: BlendMode.srcIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
