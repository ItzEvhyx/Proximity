import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/asset_icon.dart';

/// Floating bottom navigation bar.
///
/// A white rounded-rectangle bar that floats above the content with a drop
/// shadow offset to the right. Each tab shows its icon (green by default). The
/// selected tab is highlighted by a solid green rounded rectangle that slides
/// directly between tabs; its icon is masked white and its label is revealed
/// (labels stay hidden on unselected tabs).
///
/// Controlled component: the parent owns [currentIndex] and reacts to [onTap].
class NavBar extends StatelessWidget {
  const NavBar({super.key, required this.currentIndex, required this.onTap});

  /// Index of the currently selected tab.
  final int currentIndex;

  /// Fired with the tapped tab's index.
  final ValueChanged<int> onTap;

  static const List<_NavItem> _items = [
    _NavItem('Maps', 'public/assets/icons/maps_icon.png'),
    _NavItem('Routes', 'public/assets/icons/routes_icon.png'),
    _NavItem('History', 'public/assets/icons/history_icon.png'),
    _NavItem('Settings', 'public/assets/icons/settings_icon.png'),
  ];

  static const double _barHeight = 60;
  static const double _itemHeight = 46;
  static const double _barPadding = 7;
  static const double _spacing = 4;
  // Extra width the selected tab gains to fit its revealed label.
  static const double _labelExtra = 80;
  static const double _radius = 20;
  static const Duration _duration = Duration(milliseconds: 320);
  static const Curve _curve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _barHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = _items.length;
          final innerWidth = constraints.maxWidth - (2 * _barPadding);
          // Distribute the width so the selected tab is wider (icon + label)
          // and the rest are equal icon-only cells. Total stays constant, so
          // switching tabs only slides things around — it never resizes the bar.
          final collapsed =
              ((innerWidth - _labelExtra - ((count - 1) * _spacing)) / count)
                  .clamp(44.0, double.infinity);
          final expanded = collapsed + _labelExtra;

          double leftFor(int index) {
            var left = _barPadding;
            for (var i = 0; i < index; i++) {
              left += (i == currentIndex ? expanded : collapsed) + _spacing;
            }
            return left;
          }

          return DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(6, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Sliding green highlight behind the selected tab.
                AnimatedPositioned(
                  duration: _duration,
                  curve: _curve,
                  left: leftFor(currentIndex),
                  top: _barPadding,
                  width: expanded,
                  height: _itemHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(_radius - 8),
                    ),
                  ),
                ),
                // Tab cells (icons + revealed labels) on top of the highlight.
                for (var i = 0; i < count; i++)
                  AnimatedPositioned(
                    duration: _duration,
                    curve: _curve,
                    left: leftFor(i),
                    top: _barPadding,
                    width: i == currentIndex ? expanded : collapsed,
                    height: _itemHeight,
                    child: _TabCell(
                      item: _items[i],
                      selected: i == currentIndex,
                      duration: _duration,
                      curve: _curve,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A single tab: masked icon (green -> white when selected) with a label that
/// slides into view only while selected.
class _TabCell extends StatelessWidget {
  const _TabCell({
    required this.item,
    required this.selected,
    required this.duration,
    required this.curve,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final Duration duration;
  final Curve curve;
  final VoidCallback onTap;

  static const double _iconSize = 32;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRect(
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _icon(),
              AnimatedSize(
                duration: duration,
                curve: curve,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: AppColors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon() {
    return SizedBox(
      width: _iconSize,
      height: _iconSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AssetIcon(
            item.asset,
            size: _iconSize,
            color: AppColors.primary,
          ),
          // White version crossfades in when the tab is selected.
          AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: duration,
            curve: curve,
            child: AssetIcon(
              item.asset,
              size: _iconSize,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.asset);

  final String label;
  final String asset;
}
