import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'place_result.dart';

/// The dropdown card shown under the search bar. Behaves like an autocomplete
/// panel: lists nearby landmarks when the field is empty, or fuzzy search
/// matches as the user types. Tapping a row selects that place.
class SearchResultsDropdown extends StatelessWidget {
  const SearchResultsDropdown({
    super.key,
    required this.results,
    required this.loading,
    required this.showingNearby,
    required this.onSelect,
    this.error,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  final List<PlaceResult> results;
  final bool loading;
  final bool showingNearby;
  final String? error;
  final ValueChanged<PlaceResult> onSelect;

  /// When true only the header bar shows, with a chevron to reopen the list.
  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 340),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderBar(
            label: showingNearby ? 'Nearby places' : 'Results',
            collapsed: collapsed,
            onToggle: onToggleCollapse,
          ),
          if (!collapsed) Flexible(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return _MessageRow(icon: Icons.error_outline_rounded, text: error!);
    }

    if (results.isEmpty) {
      return _MessageRow(
        icon: Icons.search_off_rounded,
        text: showingNearby
            ? 'No nearby places found.'
            : 'No matching locations.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 1,
        indent: 56,
        color: AppColors.border,
      ),
      itemBuilder: (context, index) {
        final place = results[index];
        return _ResultRow(place: place, onTap: () => onSelect(place));
      },
    );
  }
}

/// Header bar shown above the results, carrying the section label and a
/// chevron button that hides (collapses) or reopens the list.
class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.label,
    required this.collapsed,
    this.onToggle,
  });

  final String label;
  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Icon(
              collapsed
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 4),
            Text(
              collapsed ? 'Show' : 'Hide',
              style: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.place, required this.onTap});

  final PlaceResult place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = place.address ?? place.categoryLabel;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(place.categoryIcon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Landmark / place name — emphasized header (Poppins bold).
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Specific address underneath (Inter).
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                    ),
                  ),
                  // Distance from the user's current location, bottom-left.
                  if (place.distanceLabel != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.near_me_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${place.distanceLabel} away',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textGrey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textGrey,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
