import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';

/// The three quick-access transit categories shown as chips below the
/// header card. Selecting one will (eventually) scope the fare matrix /
/// finder results to that line.
enum FareCategory { lrt1, lrt2, mrt }

/// Which fare column the matrix is currently displaying.
enum FareType { storedValue, singleJourney, discounted }

/// Display label for a [FareCategory], shared by the category chips, the
/// fare result summary, and the transit info card.
String _categoryLabel(FareCategory category) {
  switch (category) {
    case FareCategory.lrt1:
      return 'LRT - 1';
    case FareCategory.lrt2:
      return 'LRT - 2';
    case FareCategory.mrt:
      return 'MRT';
  }
}

/// Display label for a [FareType], shared by the fare-type row and the fare
/// result summary.
String _fareTypeLabel(FareType type) {
  switch (type) {
    case FareType.storedValue:
      return 'Stored Value';
    case FareType.singleJourney:
      return 'Single Journey';
    case FareType.discounted:
      return 'Discounted 50%';
  }
}

/// Train photo asset for a [FareCategory], used by the transit info card.
String _categoryImageAsset(FareCategory category) {
  switch (category) {
    case FareCategory.lrt1:
      return 'public/assets/images/lrt1_train_img.png';
    case FareCategory.lrt2:
      return 'public/assets/images/lrt2_train_img.png';
    case FareCategory.mrt:
      return 'public/assets/images/mrt_train_img.png';
  }
}

// TODO: this is LRT-1's real station list, used as a stand-in for every
// category for now. Swap it out for the actual per-line station list once
// that data is wired up.
const List<String> _placeholderStations = [
  'Baclaran',
  'EDSA',
  'Libertad',
  'Gil Puyat',
  'Vito Cruz',
  'Quirino',
  'Pedro Gil',
  'United Nations',
  'Central Terminal',
  'Carriedo',
  'Doroteo Jose',
  'Bambang',
  'Tayuman',
  'Blumentritt',
  'Abad Santos',
  'R. Papa',
  '5th Avenue',
  'Monumento',
];

/// "Matrix" mode content for the Routes tab.
///
/// Hosts, top to bottom:
///  1. The green gradient header card (title, money icon, description).
///  2. The LRT-1 / LRT-2 / MRT category chip row.
///  3. The Stored Value / Single Journey / Discounted (50%) fare-type row.
///  4. The "Check Your Fare" card (origin/destination dropdowns + result).
///  5. The transit info card (selected line + View Table + photo).
///
/// The full station-to-station matrix table isn't built out yet — this
/// widget currently owns the header chrome, the two selector rows, and the
/// fare-lookup chrome. Category/fare-type/origin/destination selection is
/// tracked here as local state, ready to be wired into real fare data later.
class FareMatrixTab extends StatefulWidget {
  const FareMatrixTab({super.key});

  @override
  State<FareMatrixTab> createState() => _FareMatrixTabState();
}

class _FareMatrixTabState extends State<FareMatrixTab> {
  FareCategory _category = FareCategory.lrt1;
  FareType _fareType = FareType.singleJourney;
  String? _origin;
  String? _destination;

  void _swapStations() {
    setState(() {
      final previousOrigin = _origin;
      _origin = _destination;
      _destination = previousOrigin;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The home shell positions the search bar at ~7% of screen height, with
    // the mode toggle directly below it. We need to push our content below
    // that floating overlay so nothing is hidden behind it.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topOffset = screenHeight * 0.07;
    // search bar (~52) + gap (12) + toggle (~40) + breathing room (20)
    final overlayHeight = topOffset + 52 + 12 + 40 + 20;
    // Generous deadspace below the last card so it doesn't sit flush
    // against the bottom of the screen.
    final bottomDeadspace = screenHeight * 0.15;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, overlayHeight, 20, bottomDeadspace),
      children: [
        const _FareMatrixHeaderCard(),
        const SizedBox(height: 16),
        _CategoryChipRow(
          selected: _category,
          onChanged: (category) => setState(() => _category = category),
        ),
        const SizedBox(height: 16),
        _FareTypeRow(
          selected: _fareType,
          onChanged: (type) => setState(() => _fareType = type),
        ),
        const SizedBox(height: 16),
        _CheckYourFareCard(
          origin: _origin,
          destination: _destination,
          onOriginChanged: (station) => setState(() => _origin = station),
          onDestinationChanged: (station) =>
              setState(() => _destination = station),
          onSwap: _swapStations,
          fareType: _fareType,
          category: _category,
        ),
        const SizedBox(height: 28),
        _TransitInfoCard(category: _category),
      ],
    );
  }
}

/// Shared chrome for the two white cards below the selector rows: rounded
/// white background, a thin hairline border, and a solid (unblurred) drop
/// shadow offset to the right rather than centered underneath.
class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  static const double _radius = 20;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          // Mostly solid, just a touch of blur (~20%) so the edge isn't
          // razor-sharp.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(6, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Green gradient card introducing the Fare Matrix feature: title + money
/// icon on top, short description underneath. Gradient runs left-to-right,
/// primary green fading into a slightly darker green.
class _FareMatrixHeaderCard extends StatelessWidget {
  const _FareMatrixHeaderCard();

  static const double _radius = 20;

  // Slightly darker than AppColors.primary — subtle left-to-right shift,
  // not a hard contrast change.
  static final Color _gradientEnd =
      Color.lerp(AppColors.primary, Colors.black, 0.18)!;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary, _gradientEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fare Matrix',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  height: 1.1,
                  color: AppColors.white,
                ),
              ),
              // NOTE: assumes `public/assets/icons/money_icon.png` — swap
              // the extension/path here (or switch to SvgPicture.asset) if
              // the actual asset is an SVG. No boxed background anymore —
              // just the icon itself, sized up so it reads at a glance.
              Image.asset(
                'public/assets/icons/money_icon.png',
                width: 32,
                height: 32,
                color: AppColors.white,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'A quick fare lookup tool for Metro Manila commutes — covering '
            'rail lines, buses, and other public transport options. Pick '
            'your origin and destination to instantly see the regular '
            'fare, or browse the full station-to-station matrix for stored '
            'value and single journey rates.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.4,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of the three quick category chips: LRT-1, LRT-2, MRT.
///
/// The selected chip is filled with [AppColors.primary] with white
/// text/icon; unselected chips are white with a thin green border and green
/// text/icon.
class _CategoryChipRow extends StatelessWidget {
  const _CategoryChipRow({required this.selected, required this.onChanged});

  final FareCategory selected;
  final ValueChanged<FareCategory> onChanged;

  static const List<FareCategory> _items = [
    FareCategory.lrt1,
    FareCategory.lrt2,
    FareCategory.mrt,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i != 0) const SizedBox(width: 10),
          Expanded(
            child: _CategoryChip(
              label: _categoryLabel(_items[i]),
              selected: _items[i] == selected,
              onTap: () => onChanged(_items[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Duration _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? AppColors.white : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'public/assets/icons/train_icon.png',
              width: 16,
              height: 16,
              color: foreground,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill-shaped segmented toggle for fare type: Stored Value, Single Journey,
/// Discounted (50%). Uses the same sliding-highlight pattern as [ModeToggle],
/// but — unlike that one — cells split the full available width equally
/// (via [LayoutBuilder]) and the row's height is measured up front from the
/// tallest label at up to 2 lines, so a longer label like "Discounted 50%"
/// wraps cleanly onto a second line instead of overlapping/clipping.
class _FareTypeRow extends StatelessWidget {
  const _FareTypeRow({required this.selected, required this.onChanged});

  final FareType selected;
  final ValueChanged<FareType> onChanged;

  static const List<FareType> _items = [
    FareType.storedValue,
    FareType.singleJourney,
    FareType.discounted,
  ];

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const double _cellHorizontalPadding = 8;
  static const double _cellVerticalPadding = 10;
  static const double _barPadding = 4;
  static const double _spacing = 2;
  static const double _radius = 20;
  static const Duration _duration = Duration(milliseconds: 320);
  static const Curve _curve = Curves.easeInOutCubic;

  int get _currentIndex => _items.indexOf(selected);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final cellWidth = (totalWidth -
                (2 * _barPadding) -
                ((_items.length - 1) * _spacing)) /
            _items.length;
        final textMaxWidth = cellWidth - (2 * _cellHorizontalPadding);

        // Measure the tallest label (up to 2 lines) at this cell width so
        // the row can grow to fit a wrapped label instead of clipping it.
        var tallestTextHeight = 0.0;
        for (final item in _items) {
          final painter = TextPainter(
            text: TextSpan(text: _fareTypeLabel(item), style: _labelStyle),
            maxLines: 2,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: textMaxWidth);
          if (painter.height > tallestTextHeight) {
            tallestTextHeight = painter.height;
          }
        }

        final cellHeight = tallestTextHeight + (2 * _cellVerticalPadding);
        final totalHeight = cellHeight + (2 * _barPadding);

        double leftFor(int index) =>
            _barPadding + (index * (cellWidth + _spacing));

        return SizedBox(
          width: totalWidth,
          height: totalHeight,
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
                  width: cellWidth,
                  height: cellHeight,
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
                    width: cellWidth,
                    height: cellHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(_items[i]),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: _duration,
                          curve: _curve,
                          textAlign: TextAlign.center,
                          style: _labelStyle.copyWith(
                            color: i == _currentIndex
                                ? AppColors.textDark
                                : AppColors.primary,
                          ),
                          child: Text(
                            _fareTypeLabel(_items[i]),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            softWrap: true,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// White card holding the origin/destination lookup: a "CHECK YOUR FARE"
/// header, a From/swap/To dropdown row, and the green fare result card.
class _CheckYourFareCard extends StatelessWidget {
  const _CheckYourFareCard({
    required this.origin,
    required this.destination,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onSwap,
    required this.fareType,
    required this.category,
  });

  final String? origin;
  final String? destination;
  final ValueChanged<String?> onOriginChanged;
  final ValueChanged<String?> onDestinationChanged;
  final VoidCallback onSwap;
  final FareType fareType;
  final FareCategory category;

  @override
  Widget build(BuildContext context) {
    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHECK YOUR FARE',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: 0.2,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StationDropdown(
                  label: 'From',
                  value: origin,
                  onChanged: onOriginChanged,
                ),
              ),
              const SizedBox(width: 10),
              _SwapButton(onTap: onSwap),
              const SizedBox(width: 10),
              Expanded(
                child: _StationDropdown(
                  label: 'To',
                  value: destination,
                  onChanged: onDestinationChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FareResultCard(fareType: fareType, category: category),
        ],
      ),
    );
  }
}

/// A single labeled station dropdown ("From" / "To").
class _StationDropdown extends StatelessWidget {
  const _StationDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppColors.textDark.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text(
                'Select',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textDark.withValues(alpha: 0.35),
                ),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textDark.withValues(alpha: 0.5),
              ),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textDark,
              ),
              // TODO: swap `_placeholderStations` for the real station list
              // once it's wired up.
              items: [
                for (final station in _placeholderStations)
                  DropdownMenuItem(
                    value: station,
                    child: Text(station, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Green square button between the two dropdowns that swaps origin and
/// destination. The top spacer matches the label + gap height above the
/// dropdown boxes so the button lines up with the dropdowns themselves.
class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 22),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            // NOTE: assumes `public/assets/icons/revert_icon.png` — swap
            // the extension/path here (or switch to SvgPicture.asset) if
            // the actual asset is an SVG.
            child: Image.asset(
              'public/assets/icons/revert_icon.png',
              width: 20,
              height: 20,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Green result card showing the (placeholder) computed fare plus a summary
/// of the selected fare type and category, e.g. "Single Journey • LRT - 1".
///
/// Uses the same left-to-right gradient as the header card, but blended
/// more gently so it doesn't compete with it. No shadow/blur on this card —
/// just the gradient fill and a thin border.
class _FareResultCard extends StatelessWidget {
  const _FareResultCard({required this.fareType, required this.category});

  final FareType fareType;
  final FareCategory category;

  static const double _radius = 16;

  static final Color _gradientEnd =
      Color.lerp(AppColors.primary, Colors.black, 0.08)!;

  static final Color _borderColor = AppColors.primary.withValues(alpha: 0.35);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary, _gradientEnd],
        ),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fare',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 2),
                // TODO: placeholder amount — wire up to real fare
                // calculation once station/fare data is available.
                const Text(
                  'P20',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_fareTypeLabel(fareType)} • ${_categoryLabel(category)}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

/// White card showing the selected transit line, a "View Table" button, and
/// that line's train photo.
class _TransitInfoCard extends StatelessWidget {
  const _TransitInfoCard({required this.category});

  final FareCategory category;

  @override
  Widget build(BuildContext context) {
    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _categoryLabel(category),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              _ViewTableButton(
                onTap: () {
                  // TODO: navigate to the full station-to-station matrix
                  // table for the selected category.
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TransitImage(category: category),
        ],
      ),
    );
  }
}

class _ViewTableButton extends StatelessWidget {
  const _ViewTableButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
    );
  }
}

/// Photo for the selected transit line, with a faint black overlay (10%
/// black — i.e. 90% transparent) laid on top for depth.
class _TransitImage extends StatelessWidget {
  const _TransitImage({required this.category});

  final FareCategory category;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(_categoryImageAsset(category), fit: BoxFit.cover),
            // 10% black overlay, i.e. 90% transparent.
            Container(color: Colors.black.withValues(alpha: 0.1)),
          ],
        ),
      ),
    );
  }
}