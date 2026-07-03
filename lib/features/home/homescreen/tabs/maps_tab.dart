import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../homescreen_map_renderer.dart';

/// Maps tab: the interactive Philippines map with a draggable info card sitting
/// on top of it (behind the navbar).
class MapsTab extends StatelessWidget {
  const MapsTab({super.key, this.onMapReady});

  /// Forwarded to the map so the shell knows when the map is ready to show.
  final VoidCallback? onMapReady;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: HomescreenMapRenderer(onReady: onMapReady)),
        Positioned.fill(child: _DraggableInfoCard()),
      ],
    );
  }
}

/// White card that floats over the map. Starts at 30% of the screen height and
/// can be dragged taller or shorter. Placeholder content for now.
class _DraggableInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.15,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 28),
                  const Icon(
                    Icons.construction_rounded,
                    color: AppColors.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Work in progress',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'This section is still being built. Check back soon.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.primary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
