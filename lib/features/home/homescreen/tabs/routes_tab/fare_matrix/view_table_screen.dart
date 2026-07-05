import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proximity/core/theme/app_colors.dart';
import 'package:proximity/features/home/homescreen/tabs/routes_tab/fare_matrix/fare_data_models/train_fares_data_models.dart';
import 'package:proximity/features/home/homescreen/tabs/routes_tab/fare_matrix/transit_categories.dart';

/// Full-screen landscape fare table for the selected rail line.
///
/// Forces landscape orientation on entry, restores portrait on exit.
/// Shows the full station-to-station fare matrix in a scrollable table,
/// plus quick commuter tips at the bottom.
class ViewTableScreen extends StatefulWidget {
  const ViewTableScreen({super.key, required this.category});

  final FareCategory category;

  @override
  State<ViewTableScreen> createState() => _ViewTableScreenState();
}

class _ViewTableScreenState extends State<ViewTableScreen> {
  late final FareMatrix _matrix;
  late final String _lineLabel;

  @override
  void initState() {
    super.initState();
    final line = _toRailLine(widget.category);
    _matrix = RailFareData.matrixFor(line);
    _lineLabel = fareCategoryLabel(widget.category);

    // Force landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Hide status bar for more table space
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restore portrait + system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  RailLine _toRailLine(FareCategory c) => switch (c) {
        FareCategory.lrt1 => RailLine.lrt1,
        FareCategory.lrt2 => RailLine.lrt2,
        FareCategory.mrt => RailLine.mrt3,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: Stack(
        children: [
          // Scrollable content: table + tips
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildTable(),
                const SizedBox(height: 24),
                _buildTips(),
                const SizedBox(height: 16),
                _buildFooter(),
              ],
            ),
          ),
          // Floating back button
          Positioned(
            top: 12,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x20000000)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      offset: Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color.lerp(AppColors.primary, Colors.black, 0.15)!],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Image.asset(
                'public/assets/icons/train_icon.png',
                width: 22,
                height: 22,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_lineLabel Fare Matrix',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_matrix.stationCount} stations · Regular fares (₱)',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Find FROM (row) → TO (column)',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: AppColors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final stations = _matrix.stationNames;
    final fares = _matrix.fares;
    final n = stations.length;

    // Short codes for column headers (first 7 chars)
    final codes = stations.map((s) {
      if (s.length <= 7) return s;
      return '${s.substring(0, 7)}…';
    }).toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EFE7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.primary),
          dataRowMinHeight: 36,
          dataRowMaxHeight: 36,
          headingRowHeight: 40,
          horizontalMargin: 8,
          columnSpacing: 0,
          border: TableBorder.all(
            color: const Color(0xFFE3EFE7),
            width: 0.5,
          ),
          columns: [
            DataColumn(
              label: Container(
                width: 110,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: const Text(
                  'From \\ To',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            for (var j = 0; j < n; j++)
              DataColumn(
                label: SizedBox(
                  width: 58,
                  child: Text(
                    codes[j],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
          ],
          rows: [
            for (var i = 0; i < n; i++)
              DataRow(
                color: WidgetStateProperty.resolveWith((states) {
                  return i.isEven
                      ? AppColors.white
                      : const Color(0xFFF7FAF8);
                }),
                cells: [
                  DataCell(
                    Container(
                      width: 110,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        stations[i],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: Color(0xFF12261B),
                        ),
                      ),
                    ),
                  ),
                  for (var j = 0; j < n; j++)
                    DataCell(
                      SizedBox(
                        width: 58,
                        child: Text(
                          i == j ? '—' : '₱${fares[i][j]}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight:
                                i == j ? FontWeight.w400 : FontWeight.w700,
                            fontSize: 10,
                            color: i == j
                                ? const Color(0xFF8CA096)
                                : const Color(0xFF0E8A44),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTips() {
    const tips = [
      'Get a Beep card at any station ticket booth — works across all three lines and some buses/jeepneys.',
      'Tap in when entering, tap out when exiting — your fare is calculated automatically by distance.',
      'Forget to tap out? You\'ll be charged the maximum fare on your next tap‑in.',
      'Students/seniors/PWDs get a 50% discount on all three lines with a white concessionary Beep card.',
      'Reload at station booths, 7‑Eleven, or via GCash / Maya.',
      'Transferring lines (LRT‑1 ↔ MRT‑3 at EDSA/Taft, or LRT‑2 ↔ MRT‑3 at Cubao) needs a separate fare each time.',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3EFE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick tips for first-time riders',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF12261B),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < tips.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tips[i],
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF4B5D53),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'Sources: LRTA official fare matrices (lrta.gov.ph) · LRT‑2 Stored Value '
      'Matrix, effective Aug 2, 2023 · LRMC LRT‑1 New Stored Value Fare Matrix, '
      'effective Apr 2, 2025 · DOTr MRT‑3 Regular Fare Matrix.\n'
      'Fares shown are regular (undiscounted) rates for reference — always confirm '
      'against the posted station fare matrix.',
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 10,
        height: 1.5,
        color: Color(0xFF8CA096),
      ),
      textAlign: TextAlign.center,
    );
  }
}
