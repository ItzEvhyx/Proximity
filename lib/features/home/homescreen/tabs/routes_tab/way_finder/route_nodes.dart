import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';

/// A single step/node in the route.
class RouteNode {
  final String title;
  final String eta;
  final String distance;
  final String description;
  final bool isDestination;

  const RouteNode({
    required this.title,
    required this.eta,
    required this.distance,
    required this.description,
    this.isDestination = false,
  });
}

/// Displays the step-by-step route from origin to destination as a vertical
/// timeline with green dashed connectors between nodes.
///
/// Performance: avoids IntrinsicHeight and CustomPaint (both cause jank
/// during scroll). Instead uses a simple Column layout with pre-built
/// dashed line segments from plain Container widgets.
class RouteNodesWidget extends StatelessWidget {
  const RouteNodesWidget({super.key, required this.nodes});

  final List<RouteNode> nodes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < nodes.length; i++)
          _NodeItem(
            node: nodes[i],
            isLast: i == nodes.length - 1,
          ),
        // Destination badge at the bottom
        const SizedBox(height: 8),
        const _DestinationBadge(),
        const SizedBox(height: 16),
        // Source credit
        const Center(
          child: Text(
            'Powered by Mapbox SDK',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.hintGrey,
            ),
          ),
        ),
      ],
    );
  }
}

class _NodeItem extends StatelessWidget {
  const _NodeItem({required this.node, required this.isLast});

  final RouteNode node;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline column (circle + dashed line) ─────────────────────
          Column(
            children: [
              // Circle node
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: node.isDestination
                      ? AppColors.primary
                      : AppColors.white,
                  border: Border.all(
                    color: AppColors.primary,
                    width: node.isDestination ? 0 : 2.5,
                  ),
                ),
              ),
              // Dashed connector — static column of dash segments
              if (!isLast) const _DashedSegment(),
            ],
          ),
          const SizedBox(width: 10),
          // ── Content column ─────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.3,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '~${node.eta} ${node.distance}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textDark.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  node.description,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A fixed-height dashed line segment built from plain Container widgets.
/// No CustomPaint, no IntrinsicHeight — just cheap box layout.
class _DashedSegment extends StatelessWidget {
  const _DashedSegment();

  @override
  Widget build(BuildContext context) {
    // 5 dashes with gaps — compact connector between the many route steps.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        children: List.generate(5, (i) {
          return Column(
            children: [
              Container(
                width: 2.5,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              if (i < 4) const SizedBox(height: 4),
            ],
          );
        }),
      ),
    );
  }
}

class _DestinationBadge extends StatelessWidget {
  const _DestinationBadge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              size: 16,
              color: AppColors.primary,
            ),
            SizedBox(width: 4),
            Text(
              'Destination',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
