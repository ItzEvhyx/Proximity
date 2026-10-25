import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/asset_icon.dart';

/// Floating, frosted navigation bar. The selected tab expands to reveal its
/// name while the selection pill glides between tabs.
class NavBar extends StatelessWidget {
  const NavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItem> _items = [
    _NavItem('Maps', 'public/assets/icons/maps_icon.svg'),
    _NavItem('Routes', 'public/assets/icons/routes_icon.svg'),
    _NavItem('History', null, materialIcon: Icons.history_rounded),
    _NavItem('Settings', 'public/assets/icons/settings_icon.svg'),
  ];

  static const _duration = Duration(milliseconds: 320);
  static const _curve = Curves.easeInOutCubic;
  static const _labelExtra = 64.0;
  static const _spacing = 4.0;

  @override
  Widget build(BuildContext context) {
    // An opaque, painted frost is intentional here. A live backdrop blur over
    // the Mapbox view is expensive and makes the bar look see-through while
    // the map is moving. The layered neutral gradients retain the icy-glass
    // look without that compositing cost.
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: Color(0x1AFFFFFF),
              blurRadius: 1,
              offset: Offset(0, -1),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF505056), Color(0xFF2D2D32)],
            ),
            border: Border.all(color: const Color(0xFF85858C)),
          ),
          child: SizedBox(
            height: 48,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = _items.length;
                final collapsed =
                    ((constraints.maxWidth -
                                _labelExtra -
                                _spacing * (count - 1)) /
                            count)
                        .clamp(40.0, double.infinity);
                final expanded = collapsed + _labelExtra;

                double leftFor(int index) {
                  var left = 0.0;
                  for (var i = 0; i < index; i++) {
                    left +=
                        (i == currentIndex ? expanded : collapsed) + _spacing;
                  }
                  return left;
                }

                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: _duration,
                      curve: _curve,
                      left: leftFor(currentIndex),
                      top: 0,
                      width: expanded,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF74747B), Color(0xFF4A4A50)],
                          ),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (var i = 0; i < count; i++)
                      AnimatedPositioned(
                        duration: _duration,
                        curve: _curve,
                        left: leftFor(i),
                        top: 0,
                        width: i == currentIndex ? expanded : collapsed,
                        height: 48,
                        child: _TabCell(
                          item: _items[i],
                          selected: i == currentIndex,
                          onTap: () => onTap(i),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TabCell extends StatelessWidget {
  const _TabCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.textPrimary
        : AppColors.textSecondary;
    return Semantics(
      label: item.label,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ClipRect(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.asset != null)
                  AssetIcon(item.asset!, size: 24, color: foreground)
                else
                  Icon(item.materialIcon, size: 24, color: foreground),
                AnimatedSize(
                  duration: NavBar._duration,
                  curve: NavBar._curve,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textPrimary,
                              fontSize: 13,
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
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.asset, {this.materialIcon})
    : assert(asset != null || materialIcon != null);

  final String label;
  final String? asset;
  final IconData? materialIcon;
}
