import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'fare_matrix/fare_matrix_tab.dart';
import 'way_finder/way_finder_tab.dart';

/// Which mode the routes tab is currently showing.
///
/// The toggle itself ([ModeToggle]) is rendered by the home shell directly
/// below the search bar, since the search bar sits in its own floating
/// overlay rather than inside this tab's body. This file just owns the mode
/// type, the toggle widget, and the tab content for each mode.
enum RouteMode { matrix, finder }

/// Routes tab body. Swaps between the Matrix content ([FareMatrixTab]) and
/// the Finder content depending on [mode]. Finder content isn't built out
/// yet.
class RoutesTab extends StatelessWidget {
  const RoutesTab({
    super.key,
    this.mode = RouteMode.matrix,
    this.active = false,
    this.wayFinderKey,
  });

  final RouteMode mode;

  /// Whether the Routes tab is the one currently on screen.
  final bool active;

  /// Optional key passed to the WayFinderTab for external method access.
  final GlobalKey<WayFinderTabState>? wayFinderKey;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case RouteMode.matrix:
        return FareMatrixTab(active: active);
      case RouteMode.finder:
        return WayFinderTab(key: wayFinderKey, active: active);
    }
  }
}

/// Pill-shaped segmented toggle: a white rounded rectangle slides directly
/// between "Matrix" and "Finder" behind whichever one is selected — its
/// label goes dark, the unselected label stays plain in the app's primary
/// green.
///
/// Structured like [NavBar]: fixed cell slots and a single [AnimatedPositioned]
/// highlight that slides to the selected slot on rebuild (stateless — no
/// manually driven controller). Unlike the navbar's equal-width tabs, each
/// label here keeps its own natural width (label text + padding), matching
/// the toggle's original auto-sized look rather than a fixed pixel width.
class ModeToggle extends StatelessWidget {
  const ModeToggle({super.key, required this.mode, required this.onChanged});

  final RouteMode mode;
  final ValueChanged<RouteMode> onChanged;

  static const List<_ToggleItem> _items = [
    _ToggleItem('Matrix', RouteMode.matrix),
    _ToggleItem('Finder', RouteMode.finder),
  ];

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static const double _horizontalPadding = 44;
  static const double _itemHeight = 32;
  static const double _barPadding = 4;
  static const double _spacing = 4;
  static const double _radius = 20;
  static const Duration _duration = Duration(milliseconds: 320);
  static const Curve _curve = Curves.easeInOutCubic;

  int get _currentIndex => _items.indexWhere((item) => item.mode == mode);

  double _measureTextWidth(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _labelStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.size.width;
  }

  @override
  Widget build(BuildContext context) {
    final itemWidths = [
      for (final item in _items)
        _measureTextWidth(item.label) + (2 * _horizontalPadding),
    ];

    double leftFor(int index) {
      var left = _barPadding;
      for (var i = 0; i < index; i++) {
        left += itemWidths[i] + _spacing;
      }
      return left;
    }

    final totalWidth = (2 * _barPadding) +
        itemWidths.fold<double>(0, (sum, w) => sum + w) +
        ((_items.length - 1) * _spacing);

    return SizedBox(
      width: totalWidth,
      height: _itemHeight + (2 * _barPadding),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Sliding white highlight behind the selected label.
            AnimatedPositioned(
              duration: _duration,
              curve: _curve,
              left: leftFor(_currentIndex),
              top: _barPadding,
              width: itemWidths[_currentIndex],
              height: _itemHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(_radius - 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Labels on top of the highlight.
            for (var i = 0; i < _items.length; i++)
              Positioned(
                left: leftFor(i),
                top: _barPadding,
                width: itemWidths[i],
                height: _itemHeight,
                child: _ToggleCell(
                  label: _items[i].label,
                  selected: i == _currentIndex,
                  duration: _duration,
                  curve: _curve,
                  onTap: () => onChanged(_items[i].mode),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single tappable label cell. Only its text color animates (dark when
/// selected, primary green when not) — the highlight sliding underneath does
/// the rest of the work.
class _ToggleCell extends StatelessWidget {
  const _ToggleCell({
    required this.label,
    required this.selected,
    required this.duration,
    required this.curve,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Duration duration;
  final Curve curve;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: duration,
          curve: curve,
          style: ModeToggle._labelStyle.copyWith(
            color: selected ? AppColors.textDark : AppColors.primary,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _ToggleItem {
  const _ToggleItem(this.label, this.mode);

  final String label;
  final RouteMode mode;
}