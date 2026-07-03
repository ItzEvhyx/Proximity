import 'package:flutter/material.dart';

import '../homescreen_map_renderer.dart';

/// Maps tab: the interactive Philippines map.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, this.onMapReady});

  /// Forwarded to the map so the shell knows when the map is ready to show.
  final VoidCallback? onMapReady;

  @override
  Widget build(BuildContext context) =>
      HomescreenMapRenderer(onReady: onMapReady);
}
