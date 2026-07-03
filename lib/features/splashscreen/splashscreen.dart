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

  /// An already-initialized video controller for the splash video.
  final VideoPlayerController controller;

  /// Called once the splash video has finished playing.
  final VoidCallback? onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    widget.controller
      ..addListener(_checkForCompletion)
      ..play();
  }

  void _checkForCompletion() {
    final value = widget.controller.value;
    if (!_finished &&
        value.isInitialized &&
        value.position >= value.duration &&
        !value.isPlaying) {
      _finished = true;
      widget.onFinished?.call();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkForCompletion);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: widget.controller.value.size.width,
            height: widget.controller.value.size.height,
            child: VideoPlayer(widget.controller),
          ),
        ),
      ),
    );
  }
}
