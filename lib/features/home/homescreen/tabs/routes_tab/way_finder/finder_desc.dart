import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../../core/global_services/cloudinary_services.dart';
import '../../../../../../core/theme/app_colors.dart';

/// Green/image split header card — "Way Finder" title + description on a
/// solid green left panel (~60%), with the finder map image fetched from
/// Cloudinary bleeding in on the right (~40%), blended via a left-edge fade.
class FinderDesc extends StatelessWidget {
  const FinderDesc({super.key});

  @override
  Widget build(BuildContext context) {
    final imageUrl = CloudinaryService.instance.finderMapUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 150,
        child: Stack(
          children: [
            // Base solid green background.
            const Positioned.fill(
              child: ColoredBox(color: AppColors.primary),
            ),

            // Map image pinned to the right — fetched from Cloudinary.
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: 160,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 300,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),

            // Fade overlay blending image into the green.
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: 160,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Text content on the left.
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: 100,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 0, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Way Finder',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 26,
                        height: 1.1,
                        color: AppColors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Search any location in the Philippines and get '
                      'suggested routes to get there — from jeepneys '
                      'and buses to trains.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
