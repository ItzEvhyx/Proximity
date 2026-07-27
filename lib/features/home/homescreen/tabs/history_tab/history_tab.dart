import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'past_locations/past_locations.dart';
import 'past_routes/past_routes_tab.dart';

/// Which sub-tab the history view is showing.
enum HistoryMode { locations, routes }

/// History tab with "Transit History" header, Past Locations / Past Routes
/// toggle, and timeline-based content.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  HistoryMode _mode = HistoryMode.locations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          // ── Green header with "Transit History" ──
          _TransitHistoryHeader(),
          const SizedBox(height: 16),

          // ── Tab toggle (same style as Routes tab ModeToggle, centered) ──
          Center(
            child: _HistoryModeToggle(
              mode: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
          ),
          const SizedBox(height: 8),

          // ── Clear button (same style as Finder tab) ──
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: _ClearButton(onTap: () {}),
            ),
          ),
          const SizedBox(height: 4),

          // ── Timeline content (instant switch, no delay) ──
          Expanded(
            child: _mode == HistoryMode.locations
                ? const PastLocationsTab()
                : const PastRoutesTab(),
          ),
        ],
      ),
    );
  }
}

/// Green rounded-rectangle header with "Transit History" title and bus icon.
class _TransitHistoryHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.only(top: topPadding + 12, left: 20, right: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFD4F5E0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Transit History',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.directions_bus_rounded,
              color: AppColors.primary,
              size: 38,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill-shaped segmented toggle matching the Routes tab's [ModeToggle]:
/// light green background with a sliding white pill highlight.
/// Labels: "Past Locations" / "Past Routes", centered.
class _HistoryModeToggle extends StatelessWidget {
  const _HistoryModeToggle({required this.mode, required this.onChanged});

  final HistoryMode mode;
  final ValueChanged<HistoryMode> onChanged;

  static const List<_ToggleItem> _items = [
    _ToggleItem('Past Locations', HistoryMode.locations),
    _ToggleItem('Past Routes', HistoryMode.routes),
  ];

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static const double _horizontalPadding = 28;
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
          style: _HistoryModeToggle._labelStyle.copyWith(
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
  final HistoryMode mode;
}

/// "Clear" button matching the Finder tab style: light green bg, red icon + text.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_rounded,
              size: 14,
              color: AppColors.error,
            ),
            const SizedBox(width: 4),
            const Text(
              'Clear',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
