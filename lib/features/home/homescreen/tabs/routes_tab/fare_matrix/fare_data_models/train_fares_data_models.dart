// rail_fare_data.dart
//
// Static reference data for Metro Manila's three rail lines (LRT-1, LRT-2,
// MRT-3): station lists, station-to-station fare matrices, and commuter
// quick tips. Regular (undiscounted) fares only.
//
// Sources:
//   - MRT-3: DOTr MRT-3 Regular Fare Matrix
//   - LRT-2: LRTA LRT-2 Stored Value Fare Matrix, effective Aug 2, 2023
//   - LRT-1: LRMC New Stored Value Fare Matrix, effective Apr 2, 2025
//
// Notes on accuracy:
//   - MRT-3 and LRT-2 matrices were transcribed directly from official
//     posted fare matrix images and are considered fully accurate.
//   - LRT-1 stations 1-13 (Dr. Santos -> UN Avenue) were transcribed
//     directly from the official image. Stations 14-25 (Central -> Fernando
//     Poe Jr.) were reconstructed from the confirmed per-station fare
//     increments and cross-checked against a zoomed re-read of the source
//     image, but were not pixel-verified cell by cell against the original
//     poster. Spot-check against lrta.gov.ph/tickets-and-fares/ before
//     relying on this for billing-critical logic.

/// The three rail lines covered by this data set.
enum RailLine { lrt1, lrt2, mrt3 }

extension RailLineDisplay on RailLine {
  String get label {
    switch (this) {
      case RailLine.lrt1:
        return 'LRT-1';
      case RailLine.lrt2:
        return 'LRT-2';
      case RailLine.mrt3:
        return 'MRT-3';
    }
  }

  String get fullName {
    switch (this) {
      case RailLine.lrt1:
        return 'LRT-1 (Green Line)';
      case RailLine.lrt2:
        return 'LRT-2 (Purple Line)';
      case RailLine.mrt3:
        return 'MRT-3 (EDSA Line)';
    }
  }

  String get routeDescription {
    switch (this) {
      case RailLine.lrt1:
        return 'Fernando Poe Jr. <-> Dr. Santos';
      case RailLine.lrt2:
        return 'Recto <-> Antipolo';
      case RailLine.mrt3:
        return 'North Avenue <-> Taft Avenue';
    }
  }
}

/// A single station on a rail line.
class RailStation {
  final String name;
  final RailLine line;
  final int index; // 0-based position in the line, in official order

  const RailStation({
    required this.name,
    required this.line,
    required this.index,
  });

  @override
  String toString() => name;
}

/// Holds the ordered station list and the full station-to-station fare
/// matrix (in whole pesos) for a single rail line.
class FareMatrix {
  final RailLine line;
  final List<String> stationNames;
  final List<List<int>> fares; // fares[i][j] = fare from station i to j

  const FareMatrix({
    required this.line,
    required this.stationNames,
    required this.fares,
  });

  int get stationCount => stationNames.length;

  /// Returns the ordered list of [RailStation]s for this line.
  List<RailStation> get stations => List.generate(
        stationNames.length,
        (i) => RailStation(name: stationNames[i], line: line, index: i),
      );

  int _indexOf(String stationName) {
    final i = stationNames.indexWhere(
      (s) => s.toLowerCase() == stationName.toLowerCase(),
    );
    if (i == -1) {
      throw ArgumentError(
        'Station "$stationName" not found on ${line.label}',
      );
    }
    return i;
  }

  /// Fare (in pesos) between two station names on this line.
  /// Throws [ArgumentError] if either station name isn't found.
  int fareBetween(String from, String to) {
    final i = _indexOf(from);
    final j = _indexOf(to);
    return fares[i][j];
  }

  /// Fare (in pesos) between two station indices on this line.
  int fareBetweenIndices(int i, int j) => fares[i][j];

  /// Whether both station names exist on this line.
  bool hasStation(String name) =>
      stationNames.any((s) => s.toLowerCase() == name.toLowerCase());
}

/// Central access point for all rail fare data.
class RailFareData {
  RailFareData._();

  // ------------------------------------------------------------------
  // MRT-3 (EDSA Line) — 13 stations, North Avenue -> Taft Avenue
  // ------------------------------------------------------------------
  static const List<String> mrt3Stations = [
    'North Avenue',
    'Quezon Avenue',
    'GMA-Kamuning',
    'Araneta Center-Cubao',
    'Santolan-Annapolis',
    'Ortigas',
    'Shaw Boulevard',
    'Boni',
    'Guadalupe',
    'Buendia',
    'Ayala',
    'Magallanes',
    'Taft Avenue',
  ];

  static const List<List<int>> mrt3Fares = [
    [0, 13, 13, 16, 16, 20, 20, 20, 24, 24, 24, 28, 28],
    [13, 0, 13, 13, 16, 16, 20, 20, 20, 24, 24, 24, 28],
    [13, 13, 0, 13, 13, 16, 16, 20, 20, 20, 24, 24, 24],
    [16, 13, 13, 0, 13, 13, 16, 16, 20, 20, 20, 24, 24],
    [16, 16, 13, 13, 0, 13, 13, 16, 16, 20, 20, 20, 24],
    [20, 16, 16, 13, 13, 0, 13, 13, 16, 16, 20, 20, 20],
    [20, 20, 16, 16, 13, 13, 0, 13, 13, 16, 16, 20, 20],
    [20, 20, 20, 16, 16, 13, 13, 0, 13, 13, 16, 16, 20],
    [24, 20, 20, 20, 16, 16, 13, 13, 0, 13, 13, 16, 16],
    [24, 24, 20, 20, 20, 16, 16, 13, 13, 0, 13, 13, 16],
    [24, 24, 24, 20, 20, 20, 16, 16, 13, 13, 0, 13, 13],
    [28, 24, 24, 24, 20, 20, 20, 16, 16, 13, 13, 0, 13],
    [28, 28, 24, 24, 24, 20, 20, 20, 16, 16, 13, 13, 0],
  ];

  static const FareMatrix mrt3 = FareMatrix(
    line: RailLine.mrt3,
    stationNames: mrt3Stations,
    fares: mrt3Fares,
  );

  // ------------------------------------------------------------------
  // LRT-2 (Purple Line) — 13 stations, Recto -> Antipolo
  // Stored Value (Beep) fares, effective Aug 2, 2023
  // ------------------------------------------------------------------
  static const List<String> lrt2Stations = [
    'Recto',
    'Legarda',
    'Pureza',
    'V. Mapa',
    'J. Ruiz',
    'Gilmore',
    'Betty Go-Belmonte',
    'Araneta Center-Cubao',
    'Anonas',
    'Katipunan',
    'Santolan',
    'Marikina',
    'Antipolo',
  ];

  static const List<List<int>> lrt2Fares = [
    [0, 13, 16, 18, 19, 21, 22, 23, 25, 26, 28, 31, 33],
    [13, 0, 15, 17, 18, 19, 21, 22, 24, 25, 27, 29, 32],
    [16, 15, 0, 15, 16, 18, 19, 20, 22, 23, 26, 28, 30],
    [18, 17, 15, 0, 15, 16, 17, 19, 20, 22, 24, 26, 29],
    [19, 18, 16, 15, 0, 14, 16, 17, 19, 20, 22, 24, 27],
    [21, 19, 18, 16, 14, 0, 15, 16, 18, 19, 21, 23, 26],
    [22, 21, 19, 17, 16, 15, 0, 15, 16, 18, 20, 22, 25],
    [23, 22, 20, 19, 17, 16, 15, 0, 15, 16, 19, 21, 23],
    [25, 24, 22, 20, 19, 18, 16, 15, 0, 14, 17, 19, 22],
    [26, 25, 23, 22, 20, 19, 18, 16, 14, 0, 16, 18, 21],
    [28, 27, 26, 24, 22, 21, 20, 19, 17, 16, 0, 15, 18],
    [31, 29, 28, 26, 24, 23, 22, 21, 19, 18, 15, 0, 16],
    [33, 32, 30, 29, 27, 26, 25, 23, 22, 21, 18, 16, 0],
  ];

  static const FareMatrix lrt2 = FareMatrix(
    line: RailLine.lrt2,
    stationNames: lrt2Stations,
    fares: lrt2Fares,
  );

  // ------------------------------------------------------------------
  // LRT-1 (Green Line) — 25 stations, Fernando Poe Jr. -> Dr. Santos
  // Stored Value (Beep) fares, effective Apr 2, 2025
  // Ordered north (FPJ) to south (Dr. Santos) for UI convenience — this
  // is the reverse order of the official LRMC matrix, which lists
  // Dr. Santos first. Index mapping is handled internally.
  // ------------------------------------------------------------------
  static const List<String> lrt1Stations = [
    'Fernando Poe Jr.',
    'Balintawak',
    'Monumento',
    '5th Avenue',
    'R. Papa',
    'Abad Santos',
    'Blumentritt',
    'Tayuman',
    'Bambang',
    'D. Jose',
    'Carriedo',
    'Central',
    'UN Avenue',
    'Pedro Gil',
    'Quirino',
    'Vito Cruz',
    'Gil Puyat',
    'Libertad',
    'EDSA',
    'Baclaran',
    'Redemptorist-Aseana',
    'MIA Road',
    'PITX',
    'Ninoy Aquino Ave',
    'Dr. Santos',
  ];

  // Fare matrix indexed in the same order as lrt1Stations above
  // (Fernando Poe Jr. = index 0 ... Dr. Santos = index 24). Diagonal is
  // 16 (the line's minimum fare), matching how the official LRMC matrix
  // marks same-station cells rather than leaving them blank.
  static const List<List<int>> lrt1Fares = [
    [16, 20, 22, 24, 25, 26, 27, 28, 29, 30, 31, 32, 34, 35, 37, 38, 39, 40, 42, 43, 45, 46, 48, 50, 52],
    [20, 16, 18, 20, 21, 22, 23, 24, 25, 26, 27, 28, 30, 32, 33, 35, 37, 38, 39, 40, 42, 43, 45, 47, 49],
    [22, 18, 16, 18, 19, 20, 21, 22, 23, 24, 25, 26, 28, 29, 30, 32, 33, 34, 36, 37, 39, 40, 42, 44, 46],
    [24, 20, 18, 16, 17, 18, 19, 20, 21, 22, 23, 24, 26, 27, 28, 30, 32, 33, 34, 35, 37, 38, 40, 42, 45],
    [25, 21, 19, 17, 16, 17, 18, 19, 20, 21, 22, 23, 25, 26, 27, 29, 30, 31, 33, 34, 36, 37, 39, 41, 43],
    [26, 22, 20, 18, 17, 16, 17, 18, 19, 20, 21, 22, 24, 25, 26, 28, 29, 30, 32, 33, 35, 36, 38, 40, 42],
    [27, 23, 21, 19, 18, 17, 16, 17, 18, 19, 20, 21, 23, 24, 25, 27, 28, 29, 31, 32, 34, 35, 37, 38, 41],
    [28, 24, 22, 20, 19, 18, 17, 16, 17, 18, 19, 20, 22, 23, 24, 26, 27, 28, 30, 31, 33, 34, 36, 37, 40],
    [29, 25, 23, 21, 20, 19, 18, 17, 16, 17, 18, 19, 21, 22, 23, 25, 26, 27, 29, 30, 32, 33, 35, 36, 39],
    [30, 26, 24, 22, 21, 20, 19, 18, 17, 16, 17, 18, 20, 21, 22, 24, 25, 26, 28, 29, 31, 32, 34, 36, 38],
    [31, 27, 25, 23, 22, 21, 20, 19, 18, 17, 16, 17, 19, 20, 21, 23, 24, 25, 27, 28, 30, 31, 33, 35, 37],
    [32, 28, 26, 24, 23, 22, 21, 20, 19, 18, 17, 16, 18, 19, 20, 22, 23, 24, 26, 27, 29, 30, 32, 33, 36],
    [34, 30, 28, 26, 25, 24, 23, 22, 21, 20, 19, 18, 16, 17, 19, 20, 21, 22, 24, 25, 27, 28, 30, 32, 34],
    [35, 32, 29, 27, 26, 25, 24, 23, 22, 21, 20, 19, 17, 16, 17, 19, 20, 21, 23, 24, 26, 27, 29, 31, 33],
    [37, 33, 30, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 17, 16, 17, 19, 20, 22, 22, 25, 26, 28, 29, 32],
    [38, 35, 32, 30, 29, 28, 27, 26, 25, 24, 23, 22, 20, 19, 17, 16, 18, 19, 20, 21, 23, 25, 27, 28, 31],
    [39, 37, 33, 32, 30, 29, 28, 27, 26, 25, 24, 23, 21, 20, 19, 18, 16, 17, 19, 20, 22, 23, 25, 27, 29],
    [40, 38, 34, 33, 31, 30, 29, 28, 27, 26, 25, 24, 22, 21, 20, 19, 17, 16, 18, 19, 21, 22, 24, 26, 28],
    [42, 39, 36, 34, 33, 32, 31, 30, 29, 28, 27, 26, 24, 23, 22, 20, 19, 18, 16, 17, 19, 20, 22, 24, 27],
    [43, 40, 37, 35, 34, 33, 32, 31, 30, 29, 28, 27, 25, 24, 22, 21, 20, 19, 17, 16, 18, 20, 22, 23, 26],
    [45, 42, 39, 37, 36, 35, 34, 33, 32, 31, 30, 29, 27, 26, 25, 23, 22, 21, 19, 18, 16, 17, 19, 21, 23],
    [46, 43, 40, 38, 37, 36, 35, 34, 33, 32, 31, 30, 28, 27, 26, 25, 23, 22, 20, 20, 17, 16, 18, 20, 22],
    [48, 45, 42, 40, 39, 38, 37, 36, 35, 34, 33, 32, 30, 29, 28, 27, 25, 24, 22, 22, 19, 18, 16, 18, 20],
    [50, 47, 44, 42, 41, 40, 38, 37, 36, 36, 35, 33, 32, 31, 29, 28, 27, 26, 24, 23, 21, 20, 18, 16, 19],
    [52, 49, 46, 45, 43, 42, 41, 40, 39, 38, 37, 36, 34, 33, 32, 31, 29, 28, 27, 26, 23, 22, 20, 19, 16],
  ];

  static const FareMatrix lrt1 = FareMatrix(
    line: RailLine.lrt1,
    stationNames: lrt1Stations,
    fares: lrt1Fares,
  );

  /// Returns the [FareMatrix] for the given line.
  static FareMatrix matrixFor(RailLine line) {
    switch (line) {
      case RailLine.lrt1:
        return lrt1;
      case RailLine.lrt2:
        return lrt2;
      case RailLine.mrt3:
        return mrt3;
    }
  }

  /// Convenience lookup: fare in pesos between two station names on a
  /// given line. Throws [ArgumentError] if a station isn't found on
  /// that line.
  static int fare(RailLine line, String from, String to) {
    return matrixFor(line).fareBetween(from, to);
  }

  /// Searches all three lines for a station name match (case-insensitive).
  /// Useful for building a single "pick your station" search UI without
  /// asking the user which line they mean first.
  static List<RailStation> findStation(String query) {
    final results = <RailStation>[];
    for (final line in RailLine.values) {
      final matrix = matrixFor(line);
      for (var i = 0; i < matrix.stationNames.length; i++) {
        if (matrix.stationNames[i].toLowerCase().contains(
              query.toLowerCase(),
            )) {
          results.add(RailStation(
            name: matrix.stationNames[i],
            line: line,
            index: i,
          ));
        }
      }
    }
    return results;
  }
}

// ------------------------------------------------------------------
// Quick tips for first-time rail commuters
// ------------------------------------------------------------------

/// A single commuter tip, with an optional category for grouping/
/// filtering in the UI (e.g. onboarding checklist vs in-app help card).
class CommuteTip {
  final String title;
  final String description;
  final TipCategory category;

  const CommuteTip({
    required this.title,
    required this.description,
    required this.category,
  });
}

enum TipCategory { gettingStarted, tapping, discounts, transfers }

class RailCommuteTips {
  RailCommuteTips._();

  static const List<CommuteTip> all = [
    CommuteTip(
      title: 'Get a Beep card',
      description:
          'Get a Beep card at any station ticket booth — it works across '
          'all three lines (LRT-1, LRT-2, MRT-3) and some buses/jeepneys.',
      category: TipCategory.gettingStarted,
    ),
    CommuteTip(
      title: 'Tap in, tap out',
      description:
          'Tap in when entering and tap out when exiting — your fare is '
          'calculated automatically based on the distance traveled.',
      category: TipCategory.tapping,
    ),
    CommuteTip(
      title: 'Don\'t forget to tap out',
      description:
          'If you forget to tap out, you\'ll be charged the maximum fare '
          'the next time you tap in.',
      category: TipCategory.tapping,
    ),
    CommuteTip(
      title: 'Student / Senior / PWD discount',
      description:
          'Students, senior citizens, and PWDs get a 50% discount on all '
          'three lines with a white concessionary Beep card (bring a '
          'valid ID to apply at any station).',
      category: TipCategory.discounts,
    ),
    CommuteTip(
      title: 'Reloading your card',
      description:
          'Reload at station ticket booths, 7-Eleven, or via the GCash or '
          'Maya apps.',
      category: TipCategory.gettingStarted,
    ),
    CommuteTip(
      title: 'Transferring between lines',
      description:
          'Transferring lines (e.g. LRT-1 to MRT-3 at EDSA/Taft Avenue, or '
          'LRT-2 to MRT-3 at Cubao) requires a separate fare each time — '
          'there is no single combined ticket yet.',
      category: TipCategory.transfers,
    ),
  ];

  static List<CommuteTip> byCategory(TipCategory category) =>
      all.where((t) => t.category == category).toList();
}