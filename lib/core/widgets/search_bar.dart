import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Floating location search bar shared by the Maps and Routes tabs.
///
/// A white pill with the brand alarm-clock icon, an underlined "Search
/// Location..." placeholder, and microphone + search icons (from the Material
/// icon library) on the right. Presentational for now — [onTap], [onMicTap] and
/// [onSearchTap] are wired by the caller once search is implemented.
class LocationSearchBar extends StatelessWidget {
  const LocationSearchBar({
    super.key,
    this.hintText = 'Search Location...',
    this.onTap,
    this.onMicTap,
    this.onSearchTap,
  });

  final String hintText;
  final VoidCallback? onTap;
  final VoidCallback? onMicTap;
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(
              'public/assets/icons/alarm_clock_icon.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
              color: AppColors.primary,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                hintText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.hintGrey,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.hintGrey,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ActionIcon(icon: Icons.mic_none_rounded, onTap: onMicTap),
            const SizedBox(width: 10),
            _ActionIcon(icon: Icons.search_rounded, onTap: onSearchTap ?? onTap),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(icon, color: AppColors.primary, size: 30),
    );
  }
}
