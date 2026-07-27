import 'package:flutter/material.dart';

/// Animated tab host that slides directly toward the newly selected tab: the
/// incoming tab enters from the right when moving to a higher index and from
/// the left when moving to a lower one (so Maps -> Profile slides straight over
/// to Profile).
///
/// Every tab is kept in the tree (state preserved) so switching away and back
/// doesn't re-initialize a tab — e.g. the map is never torn down and reloaded.
class TabsTransition extends StatefulWidget {
  const TabsTransition({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 320),
    this.curve = Curves.easeInOutCubic,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;

  @override
  State<TabsTransition> createState() => _TabsTransitionState();
}

class _TabsTransitionState extends State<TabsTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _currentIndex;
  int _previousIndex = 0;
  int _direction = 1;

  /// Tracks which tab indices have been visited at least once. Tabs not in
  /// this set render as SizedBox.shrink() (zero build cost) until first shown.
  final Set<int> _builtTabs = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    // The initial tab is immediately visible — mark it as built.
    _builtTabs.add(_currentIndex);
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    )..addStatusListener((status) {
        // Rebuild once the slide finishes so the outgoing tab goes offstage.
        if (status == AnimationStatus.completed && mounted) setState(() {});
      });
  }

  @override
  void didUpdateWidget(covariant TabsTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _currentIndex) {
      _previousIndex = _currentIndex;
      _direction = widget.index > _currentIndex ? 1 : -1;
      _currentIndex = widget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = widget.curve.transform(_controller.value);
        final animating = _controller.isAnimating;
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _buildLayer(i, t, animating),
          ],
        );
      },
    );
  }

  Widget _buildLayer(int index, double t, bool animating) {
    final isCurrent = index == _currentIndex;
    final isPrevious = index == _previousIndex && animating;
    final visible = isCurrent || isPrevious;

    // Lazy building: track which tabs have ever been visible. Once a tab
    // has been built once, it stays in the tree (state preserved). Tabs
    // that have NEVER been visited get an empty SizedBox — zero build cost.
    if (isCurrent && !_builtTabs.contains(index)) {
      _builtTabs.add(index);
    }

    final hasBeenBuilt = _builtTabs.contains(index);

    // Kill tabs that are not currently active and not animating out.
    // Exception: index 0 (Maps) is always kept alive to avoid expensive
    // map re-initialization.
    if (!visible && index != 0) {
      return const SizedBox.shrink();
    }

    double dx = 0;
    if (isCurrent) {
      dx = _direction * (1 - t);
    } else if (isPrevious) {
      dx = -_direction * t;
    }

    return Offstage(
      offstage: !visible,
      child: IgnorePointer(
        ignoring: !isCurrent,
        child: FractionalTranslation(
          translation: Offset(dx, 0),
          child: hasBeenBuilt
              ? widget.children[index]
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
