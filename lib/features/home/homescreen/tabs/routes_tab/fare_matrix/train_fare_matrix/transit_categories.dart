import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../../../core/global_services/cloudinary_services.dart';
import '../../../../../../../core/skeleton_loading/skeleton_loading.dart';
import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/widgets/asset_icon.dart';
import '../../../../../../../core/widgets/card_dropshadow.dart';
import 'view_table_screen.dart';

/// Available transit line categories.
enum FareCategory { lrt1, lrt2, mrt }

/// Display label for a [FareCategory].
String fareCategoryLabel(FareCategory c) => switch (c) {
      FareCategory.lrt1 => 'LRT - 1',
      FareCategory.lrt2 => 'LRT - 2',
      FareCategory.mrt => 'MRT',
    };

/// Cloudinary delivery URL for a [FareCategory]'s train photo.
String _categoryImageUrl(FareCategory c) {
  final s = CloudinaryService.instance;
  return switch (c) {
    FareCategory.lrt1 => s.lrt1TrainUrl,
    FareCategory.lrt2 => s.lrt2TrainUrl,
    FareCategory.mrt => s.mrtTrainUrl,
  };
}

/// Row of category chips: LRT-1, LRT-2, MRT.
/// No animations — selected state renders instantly.
class TransitCategoryChips extends StatelessWidget {
  const TransitCategoryChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final FareCategory selected;
  final ValueChanged<FareCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < FareCategory.values.length; i++) ...[
          if (i != 0) const SizedBox(width: 10),
          Expanded(
            child: _Chip(
              category: FareCategory.values[i],
              selected: FareCategory.values[i] == selected,
              onTap: () => onChanged(FareCategory.values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final FareCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.white : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AssetIcon(
              'public/assets/icons/train_icon.png',
              size: 16,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              fareCategoryLabel(category),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transit info card — shows the selected line name, "View Table" button,
/// and a Cloudinary-hosted train photo with skeleton loading.
///
/// The image uses [AutomaticKeepAliveClientMixin] so the decoded bitmap
/// survives being scrolled out of view and doesn't re-decode on scroll-back.
class TransitInfoCard extends StatelessWidget {
  const TransitInfoCard({
    super.key,
    required this.category,
    required this.loadImage,
  });

  final FareCategory category;
  final bool loadImage;

  @override
  Widget build(BuildContext context) {
    return DropShadowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fareCategoryLabel(category),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ViewTableScreen(category: category),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'View Table',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TrainImage(
            url: _categoryImageUrl(category),
            load: loadImage,
          ),
        ],
      ),
    );
  }
}

/// Cached network image with keep-alive. Zero fade animation.
class _TrainImage extends StatefulWidget {
  const _TrainImage({required this.url, required this.load});

  final String url;
  final bool load;

  @override
  State<_TrainImage> createState() => _TrainImageState();
}

class _TrainImageState extends State<_TrainImage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final shouldLoad = widget.load && widget.url.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: shouldLoad
            ? CachedNetworkImage(
                imageUrl: widget.url,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (_, _) => const SkeletonBox(borderRadius: 0),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: AppColors.surfaceMuted,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.hintGrey,
                    ),
                  ),
                ),
              )
            : const SkeletonBox(borderRadius: 0),
      ),
    );
  }
}
