import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_colors.dart';
import '../forgot_password/enter_new_password_card.dart';
import '../forgot_password/forgot_pass_card.dart';
import '../forgot_password/forgot_password_service.dart';
import '../forgot_password/password_reset_card.dart';
import '../signup/signup_card.dart';
import '../signup/signup_otp_card.dart';
import '../signup/signup_services.dart';
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
    with TickerProviderStateMixin {
  static const double _busHeight = 150;
  static const double _busWidth = 265;
  // How far the bus box is nudged down behind the card, so the Lottie's
  // built-in transparent bottom padding is hidden under the card.
  static const double _busCardOverlap = 40;

  // Fraction of the screen height taken up by each card. The sign up card is
  // taller because it holds more fields, so the bus (clamped to the top of the
  // active card) rides higher when the sign up card is shown.
  static const double _loginHeightFactor = 0.66;
  static const double _signUpHeightFactor = 0.82;
  // The forgot-password card is the same height as the login card.
  static const double _forgotHeightFactor = 0.66;
  // The password-reset (OTP) card is a little taller to fit the OTP boxes.
  static const double _resetHeightFactor = 0.74;
  // The sign-up email-verification (OTP) card, same height as the sign up card.
  static const double _signupOtpHeightFactor = 0.82;
  // The set-new-password card, same height as the login/forgot cards.
  static const double _newPasswordHeightFactor = 0.66;

  // Sequence: background + text render first -> the login card slides up from
  // the bottom (_entranceController) -> the bus Lottie mounts 2s after load so
  // it never renders during the transition (keeps everything smooth).
  //
  // _switchController drives the login <-> sign up swap. 0 = login shown,
  // 1 = sign up shown. The first half slides the login card down out of view,
  // the second half slides the sign up card up into view, so it reads as
  // "slide down login, then slide up sign up".
  late final AnimationController _entranceController;
  late final AnimationController _switchController;
  // Drives the login <-> forgot-password swap, mirroring _switchController.
  late final AnimationController _forgotController;
  // Drives the forgot-password <-> reset (OTP) swap, mirroring the above.
  late final AnimationController _resetController;
  // Drives the sign up <-> email-verification (OTP) swap.
  late final AnimationController _signupOtpController;
  // Drives the reset (OTP) <-> set-new-password swap.
  late final AnimationController _newPasswordController;

  // Shared sign-up service (holds the pending sign-up + issued code) passed to
  // both the sign up card and its OTP card. The email the code was sent to is
  // kept here so it can be shown on the OTP card.
  final SignUpService _signUpService = SignUpService();
  String _pendingSignupEmail = '';

  // Shared forgot-password service (holds the pending reset + issued code),
  // passed to the forgot / reset / new-password cards. The email the code was
  // sent to is kept here for display on the reset card.
  final ForgotPasswordService _forgotService = ForgotPasswordService();
  String _pendingForgotEmail = '';

  // Eased views of the raw controllers. Reading the curved value (instead of
  // the linear controller value) is what makes the slide feel smooth rather
  // than mechanical, without changing any of the position math below.
  late final Animation<double> _entrance;
  late final Animation<double> _switch;
  late final Animation<double> _forgot;
  late final Animation<double> _reset;
  late final Animation<double> _signupOtp;
  late final Animation<double> _newPassword;

  bool _showBus = false;
  Timer? _cardTimer;
  Timer? _busTimer;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _switchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _forgotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _signupOtpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _newPasswordController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );

    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _switch = CurvedAnimation(
      parent: _switchController,
      curve: Curves.easeInOutCubic,
    );
    _forgot = CurvedAnimation(
      parent: _forgotController,
      curve: Curves.easeInOutCubic,
    );
    _reset = CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeInOutCubic,
    );
    _signupOtp = CurvedAnimation(
      parent: _signupOtpController,
      curve: Curves.easeInOutCubic,
    );
    _newPassword = CurvedAnimation(
      parent: _newPasswordController,
      curve: Curves.easeInOutCubic,
    );

    // Let the background + text land first, then slide the card up.
    _cardTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _entranceController.forward();
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
    _entranceController.dispose();
    _switchController.dispose();
    _forgotController.dispose();
    _resetController.dispose();
    _signupOtpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _goToSignUp() {
    FocusScope.of(context).unfocus();
    _switchController.forward();
  }

  void _backFromSignUp() {
    FocusScope.of(context).unfocus();
    _switchController.reverse();
  }

  void _goToForgot() {
    FocusScope.of(context).unfocus();
    _forgotController.forward();
  }

  void _backFromForgot() {
    FocusScope.of(context).unfocus();
    _forgotController.reverse();
  }

  void _goToReset(String email) {
    FocusScope.of(context).unfocus();
    setState(() => _pendingForgotEmail = email);
    _resetController.forward();
  }

  void _backFromReset() {
    FocusScope.of(context).unfocus();
    _resetController.reverse();
  }

  void _goToSignupOtp(String email) {
    FocusScope.of(context).unfocus();
    setState(() => _pendingSignupEmail = email);
    _signupOtpController.forward();
  }

  void _backFromSignupOtp() {
    FocusScope.of(context).unfocus();
    _signupOtpController.reverse();
  }

  /// After a successful sign-up: slide the OTP card down and the login card
  /// back up. Reversing both controllers together reads as "drop the OTP card,
  /// then raise login" — the same staggered feel as the other transitions.
  void _finishSignupToLogin() {
    FocusScope.of(context).unfocus();
    _signupOtpController.reverse();
    _switchController.reverse();
  }

  void _goToNewPassword() {
    FocusScope.of(context).unfocus();
    _newPasswordController.forward();
  }

  void _backFromNewPassword() {
    FocusScope.of(context).unfocus();
    _newPasswordController.reverse();
  }

  /// After setting a new password: slide the whole forgot-password chain
  /// (new-password -> reset -> forgot) back down and raise the login card.
  void _finishForgotToLogin() {
    FocusScope.of(context).unfocus();
    _newPasswordController.reverse();
    _resetController.reverse();
    _forgotController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenHeight = mq.size.height;
    final loginHeight = screenHeight * _loginHeightFactor;
    final signUpHeight = screenHeight * _signUpHeightFactor;
    final forgotHeight = screenHeight * _forgotHeightFactor;
    final resetHeight = screenHeight * _resetHeightFactor;
    final signupOtpHeight = screenHeight * _signupOtpHeightFactor;
    final newPasswordHeight = screenHeight * _newPasswordHeightFactor;

    // Build each card exactly once per screen build (not once per animation
    // frame). Wrapping them in RepaintBoundary gives each its own cached
    // layer, so the per-frame Transform.translate below only re-composites an
    // existing raster instead of repainting the card's contents (TextFields,
    // borders, images). This is what keeps the slide smooth. The identical
    // widget instances are reused across frames, so their subtrees never
    // rebuild while animating.
    final loginCard = RepaintBoundary(
      child: LoginCard(
        onSignUp: _goToSignUp,
        onForgotPassword: _goToForgot,
      ),
    );
    final signUpCard = RepaintBoundary(
      child: SignUpCard(
        service: _signUpService,
        onBack: _backFromSignUp,
        onOtpSent: _goToSignupOtp,
      ),
    );
    final signupOtpCard = RepaintBoundary(
      child: SignUpOtpCard(
        service: _signUpService,
        email: _pendingSignupEmail,
        onBack: _backFromSignupOtp,
        onVerified: _finishSignupToLogin,
      ),
    );
    final forgotCard = RepaintBoundary(
      child: ForgotPassCard(
        service: _forgotService,
        onBack: _backFromForgot,
        onOtpSent: _goToReset,
      ),
    );
    final resetCard = RepaintBoundary(
      child: PasswordResetCard(
        service: _forgotService,
        email: _pendingForgotEmail,
        onBack: _backFromReset,
        onConfirmed: _goToNewPassword,
      ),
    );
    final newPasswordCard = RepaintBoundary(
      child: EnterNewPasswordCard(
        service: _forgotService,
        onBack: _backFromNewPassword,
        onConfirmed: _finishForgotToLogin,
      ),
    );

    return Scaffold(
      // The card frame stays anchored to the bottom; each card handles the
      // keyboard internally by scrolling only its own contents up.
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gradientTop, AppColors.gradientBottom],
          ),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge(
            [
              _entranceController,
              _switchController,
              _forgotController,
              _resetController,
              _signupOtpController,
              _newPasswordController,
            ],
          ),
          builder: (context, child) {
            final entrance = _entrance.value; // 0..1 (eased)
            final switchV = _switch.value; // 0..1 (login<->sign up)
            final forgotV = _forgot.value; // 0..1 (login<->forgot)
            final resetV = _reset.value; // 0..1 (forgot<->reset)
            final signupOtpV = _signupOtp.value; // 0..1 (sign up<->otp)
            final newPwV = _newPassword.value; // 0..1 (reset<->new password)

            // Staggered progress: phase 1 (0..0.5) drops the source card,
            // phase 2 (0.5..1) raises the target card. Only one of the swaps
            // is ever active at a time.
            final signUpDrop = (switchV / 0.5).clamp(0.0, 1.0);
            final forgotDrop = (forgotV / 0.5).clamp(0.0, 1.0);
            final resetDrop = (resetV / 0.5).clamp(0.0, 1.0);
            final signupOtpDrop = (signupOtpV / 0.5).clamp(0.0, 1.0);
            final newPwDrop = (newPwV / 0.5).clamp(0.0, 1.0);
            final signUpProgress = ((switchV - 0.5) / 0.5).clamp(0.0, 1.0);
            final forgotProgress = ((forgotV - 0.5) / 0.5).clamp(0.0, 1.0);
            final resetProgress = ((resetV - 0.5) / 0.5).clamp(0.0, 1.0);
            final signupOtpProgress =
                ((signupOtpV - 0.5) / 0.5).clamp(0.0, 1.0);
            final newPwProgress = ((newPwV - 0.5) / 0.5).clamp(0.0, 1.0);

            // The login card drops for whichever login-level swap is active.
            final loginDrop =
                signUpDrop > forgotDrop ? signUpDrop : forgotDrop;

            // Downward translate (px) applied to each card. Positive = below.
            final loginTranslateY =
                (1 - entrance) * loginHeight + loginDrop * loginHeight;
            // The sign up card is raised into view, then dropped again when
            // the email-verification (OTP) card takes over.
            final signUpTranslateY = (1 - signUpProgress) * signUpHeight +
                signupOtpDrop * signUpHeight;
            // The forgot card is raised into view, then dropped again when the
            // reset card takes over.
            final forgotTranslateY =
                (1 - forgotProgress) * forgotHeight + resetDrop * forgotHeight;
            // The reset card is raised into view, then dropped again when the
            // set-new-password card takes over.
            final resetTranslateY =
                (1 - resetProgress) * resetHeight + newPwDrop * resetHeight;
            final signupOtpTranslateY =
                (1 - signupOtpProgress) * signupOtpHeight;
            final newPwTranslateY = (1 - newPwProgress) * newPasswordHeight;

            // Top edge (distance from the screen bottom) of each card.
            final loginTop = loginHeight - loginTranslateY;
            final signUpTop = signUpHeight - signUpTranslateY;
            final forgotTop = forgotHeight - forgotTranslateY;
            final resetTop = resetHeight - resetTranslateY;
            final signupOtpTop = signupOtpHeight - signupOtpTranslateY;
            final newPwTop = newPasswordHeight - newPwTranslateY;

            // The bus is clamped to the top edge of whichever card is the
            // active (topmost visible) one, minus the overlap that hides the
            // Lottie's transparent bottom padding under the card.
            // For the sub-0.5 (source) half we use max(sourceTop, loginTop):
            // in a forward transition the source card is highest, but when
            // returning to login (reversing the chain together) the login card
            // is the one rising, so the bus should follow it.
            final double activeTop;
            if (newPwV > 0) {
              activeTop = newPwV < 0.5
                  ? math.max(resetTop, loginTop)
                  : newPwTop;
            } else if (signupOtpV > 0) {
              activeTop = signupOtpV < 0.5
                  ? math.max(signUpTop, loginTop)
                  : signupOtpTop;
            } else if (switchV > 0) {
              activeTop = switchV < 0.5 ? loginTop : signUpTop;
            } else if (resetV > 0) {
              activeTop = resetV < 0.5 ? forgotTop : resetTop;
            } else if (forgotV > 0) {
              activeTop = forgotV < 0.5 ? loginTop : forgotTop;
            } else {
              activeTop = loginTop;
            }
            final busBottom = activeTop - _busCardOverlap;

            // The header (Proximity title + tagline) fades out only for the
            // sign up swap; the forgot-password card keeps it (same height).
            final headerOpacity = (1 - switchV).clamp(0.0, 1.0);

            return Stack(
              children: [
                // Title + tagline, shown while login/forgot cards are up.
                if (headerOpacity > 0)
                  Positioned(
                    key: const ValueKey('auth-header'),
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      ignoring: headerOpacity < 1,
                      child: Opacity(
                        opacity: headerOpacity,
                        child: const _AuthHeader(),
                      ),
                    ),
                  ),
                // Animated bus, nudged down behind the card so its transparent
                // bottom padding is hidden. It travels the full width and
                // loops, and rides up/down as the active card changes height.
                if (_showBus)
                  Positioned(
                    // A stable key keeps the bus's State (and its running
                    // Lottie/movement) alive even as sibling children (like the
                    // header) are added/removed, so the animation never resets
                    // mid-transition.
                    key: const ValueKey('moving-bus'),
                    left: 0,
                    right: 0,
                    bottom: busBottom,
                    height: _busHeight,
                    child: const _MovingBus(
                      busWidth: _busWidth,
                      busHeight: _busHeight,
                    ),
                  ),
                // Sign up card, anchored to the bottom and hidden below until
                // it is raised in phase 2.
                Positioned(
                  key: const ValueKey('signup-card'),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: signUpHeight,
                  child: Transform.translate(
                    offset: Offset(0, signUpTranslateY),
                    child: signUpCard,
                  ),
                ),
                // Sign-up email-verification (OTP) card, raised over the sign
                // up card once the code has been emailed.
                Positioned(
                  key: const ValueKey('signup-otp-card'),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: signupOtpHeight,
                  child: Transform.translate(
                    offset: Offset(0, signupOtpTranslateY),
                    child: signupOtpCard,
                  ),
                ),
                // Forgot-password card, anchored to the bottom and hidden below
                // until it is raised in phase 2.
                Positioned(
                  key: const ValueKey('forgot-card'),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: forgotHeight,
                  child: Transform.translate(
                    offset: Offset(0, forgotTranslateY),
                    child: forgotCard,
                  ),
                ),
                // Password-reset (OTP) card, anchored to the bottom and hidden
                // below until it is raised in phase 2 of the reset swap.
                Positioned(
                  key: const ValueKey('reset-card'),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: resetHeight,
                  child: Transform.translate(
                    offset: Offset(0, resetTranslateY),
                    child: resetCard,
                  ),
                ),
                // Set-new-password card, raised over the reset card once the
                // forgot-password OTP has been confirmed.
                Positioned(
                  key: const ValueKey('new-password-card'),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: newPasswordHeight,
                  child: Transform.translate(
                    offset: Offset(0, newPwTranslateY),
                    child: newPasswordCard,
                  ),
                ),
                // Login card, anchored to the bottom. Slides up on entrance
                // and slides down when swapping to sign up or forgot password.
                Positioned(
                  key: const ValueKey('login-card'),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: loginHeight,
                  child: Transform.translate(
                    offset: Offset(0, loginTranslateY),
                    child: loginCard,
                  ),
                ),
              ],
            );
          },
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
