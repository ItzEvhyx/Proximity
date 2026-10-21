import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';

/// Full-screen video splash shown right after the native splash screen.
///
/// The controller is initialized in `main()` before the first frame so the
/// video can start immediately, with no gap after the native splash. The
/// [splashscreen.mp4] video fills the entire screen (cropped to cover, keeping
/// its aspect ratio) and is centered. When playback finishes the [onFinished]
/// callback is invoked so the app can move on to the next screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.controller, this.onFinished});

  /// An already-initialized controller for the splash video. A null value
  /// displays a short black fallback when a device cannot decode the video.
  final VideoPlayerController? controller;

  /// Called once the splash video has finished playing.
  final VoidCallback? onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _finished = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    final controller = widget.controller;
    if (controller == null) {
      _fallbackTimer = Timer(const Duration(milliseconds: 900), _finish);
      return;
    }

    controller.addListener(_checkForCompletion);
    unawaited(controller.play());

    // A broken media callback must not be able to hold the user on the splash
    // forever. The normal completion listener still transitions sooner.
    final duration = controller.value.duration;
    _fallbackTimer = Timer(
      duration > Duration.zero
          ? duration + const Duration(seconds: 2)
          : const Duration(seconds: 8),
      _finish,
    );
  }

  void _checkForCompletion() {
    final controller = widget.controller;
    if (controller == null) return;
    final value = controller.value;
    if (!_finished &&
        value.isInitialized &&
        value.position >= value.duration &&
        !value.isPlaying) {
      _finish();
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _fallbackTimer?.cancel();
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    widget.controller?.removeListener(_checkForCompletion);
    widget.controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SizedBox.expand(
        child: controller == null
            ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
      ),
    );
  }
}
