import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'past_locations/past_locations.dart';
import 'past_routes/past_routes_tab.dart';

/// History tab with "Transit History" header, Past Locations / Past Routes
/// toggle, and timeline-based content.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  int _selectedTab = 0; // 0 = Past Locations, 1 = Past Routes

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          // ── Green header with "Transit History" ──
          _TransitHistoryHeader(),
          const SizedBox(height: 16),

          // ── Tab toggle: Past Locations / Past Routes (centered) ──
          Center(
            child: _HistoryTabToggle(
              selectedIndex: _selectedTab,
              onChanged: (index) => setState(() => _selectedTab = index),
            ),
          ),
          const SizedBox(height: 8),

          // ── Clear button ──
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: _ClearButton(onTap: () {}),
            ),
          ),
          const SizedBox(height: 4),

          // ── Timeline content with crossfade animation ──
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: _selectedTab == 0
                  ? const PastLocationsTab(key: ValueKey(0))
                  : const PastRoutesTab(key: ValueKey(1)),
            ),
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

/// Tab toggle for "Past Locations" / "Past Routes" — same sliding-highlight
/// style as the Routes tab's [ModeToggle]. Two centered labels with a white
/// pill that slides to the selected one.
class _HistoryTabToggle extends StatelessWidget {
  const _HistoryTabToggle({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const List<String> _labels = ['Past Locations', 'Past Routes'];

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static const double _horizontalPadding = 28;
  static const double _itemHeight = 34;
  static const double _barPadding = 4;
  static const double _spacing = 4;
  static const double _radius = 20;
  static const Duration _duration = Duration(milliseconds: 320);
  static const Curve _curve = Curves.easeInOutCubic;

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
      for (final label in _labels)
        _measureTextWidth(label) + (2 * _horizontalPadding),
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
        ((_labels.length - 1) * _spacing);

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
            // Sliding white highlight
            AnimatedPositioned(
              duration: _duration,
              curve: _curve,
              left: leftFor(selectedIndex),
              top: _barPadding,
              width: itemWidths[selectedIndex],
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
            // Labels
            for (var i = 0; i < _labels.length; i++)
              Positioned(
                left: leftFor(i),
                top: _barPadding,
                width: itemWidths[i],
                height: _itemHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: _duration,
                      curve: _curve,
                      style: _labelStyle.copyWith(
                        color: i == selectedIndex
                            ? AppColors.textDark
                            : AppColors.primary,
                      ),
                      child: Text(_labels[i]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Clear" button with trash icon.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 4),
            Text(
              'Clear',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
