import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_colors.dart';
import 'login_card.dart';

/// Preloads and caches the bus Lottie composition so it is fully decoded
/// before the login screen appears, avoiding jank during the splash->login
/// transition. Call [preload] early (e.g. in main).
class BusAnimation {
  const BusAnimation._();

  static const String asset = 'public/assets/logos/bus_vehicle.lottie';
  static Future<LottieComposition?>? _future;

  static Future<LottieComposition?> preload() =>
      _future ??= AssetLottie(asset).load();
}

/// Auth screen shared by login and (soon) sign up. It owns the branded green
/// gradient background and the global header (title + tagline + animated bus)
/// that sits clamped in the green area above the card.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const double _busHeight = 150;
  static const double _busWidth = 265;
  // How far the bus box is nudged down behind the card, so the Lottie's
  // built-in transparent bottom padding is hidden under the card.
  static const double _busCardOverlap = 40;

  // Sequence: background + text render first -> the card slides up from the
  // bottom -> the bus Lottie mounts 2s after load so it never renders during
  // the transition (keeps everything smooth) and looks like it "just arrived".
  late final AnimationController _cardController;
  late final Animation<Offset> _cardSlide;
  bool _showBus = false;
  Timer? _cardTimer;
  Timer? _busTimer;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );

    // Let the background + text land first, then slide the card up.
    _cardTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _cardController.forward();
    });
    // Bring the bus in 2s after load.
    _busTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showBus = true);
    });
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    _busTimer?.cancel();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Card pushed down a bit -> occupies 66% of the height at the bottom.
    final cardHeight = screenHeight * 0.66;

    return Scaffold(
      // The card frame stays fixed; only its inner content scrolls with the
      // keyboard.
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gradientTop, AppColors.gradientBottom],
          ),
        ),
        child: Stack(
          children: [
            // Title + tagline, pushed a bit lower from the top.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _AuthHeader(),
            ),
            // Animated bus, nudged down behind the card so its transparent
            // bottom padding is hidden. Mounted 1.5s after load so it drives
            // in like it just arrived. It travels the full width and loops.
            if (_showBus)
              Positioned(
                left: 0,
                right: 0,
                bottom: cardHeight - _busCardOverlap,
                height: _busHeight,
                child: const _MovingBus(
                  busWidth: _busWidth,
                  busHeight: _busHeight,
                ),
              ),
            // Card anchored to the bottom, sliding up from below on load.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: cardHeight,
              child: SlideTransition(
                position: _cardSlide,
                child: const LoginCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Branding header: the Proximity title + tagline, with a solid drop shadow.
class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Padding(
      // Extra top padding pushes the text lower from the device top.
      padding: EdgeInsets.only(left: 22, right: 22, top: topPadding + 46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Transform.translate(
                offset: const Offset(3, 3),
                child: const _TitleBlock(color: AppColors.titleShadow),
              ),
              const _TitleBlock(color: Colors.white),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Sleep through your commute, not your stop.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w300,
              color: Colors.white,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "[icon] Proximity" row plus the "Welcome, Commuter!" line, rendered in a
/// single color so it can be stacked to produce the solid backdrop shadow.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'public/assets/logos/proximity_icon_white.png',
              height: 24,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              'Proximity',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                height: 1.0,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          'Welcome, Commuter!',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w800,
            fontSize: 24,
            height: 1.1,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Bus that plays its Lottie loop while translating horizontally across the
/// full device width. It enters 15px from the left edge, drives to 15px from
/// the right edge, then instantly loops back to the start (disappears at the
/// exit point, reappears at the start).
class _MovingBus extends StatefulWidget {
  const _MovingBus({
    required this.busWidth,
    required this.busHeight,
  });

  final double busWidth;
  final double busHeight;

  @override
  State<_MovingBus> createState() => _MovingBusState();
}

class _MovingBusState extends State<_MovingBus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _moveController;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.busHeight,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Enter fully off the left edge, exit fully off the right edge.
          // The reset happens while the bus is off-screen, so there is no
          // visible jump/restart -- it just reappears from the left.
          final startX = -widget.busWidth;
          final endX = constraints.maxWidth;
          final range = endX - startX;
          return AnimatedBuilder(
            animation: _moveController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(startX + range * _moveController.value, 0),
                child: child,
              );
            },
            child: SizedBox(
              width: widget.busWidth,
              height: widget.busHeight,
              child: FutureBuilder<LottieComposition?>(
                future: BusAnimation.preload(),
                builder: (context, snapshot) {
                  final composition = snapshot.data;
                  if (composition == null) {
                    return const SizedBox.shrink();
                  }
                  return Lottie(
                    composition: composition,
                    fit: BoxFit.contain,
                    // Bottom-align so the bus sits flush on the card's top
                    // edge instead of floating in the middle of its box.
                    alignment: Alignment.bottomCenter,
                    repeat: true,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
