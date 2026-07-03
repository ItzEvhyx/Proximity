import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'core/animations/screen_transitions.dart';
import 'core/config/env.dart';
import 'core/network/network_service.dart';
import 'core/router/app_router.dart';
import 'core/session/user_session.dart';
import 'core/shared_prefs/shared_prefs.dart';
import 'core/supabase/supabase_client.dart';
import 'features/login/login_screen.dart';
import 'features/network_error/network_error_screen.dart';
import 'features/splashscreen/splashscreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load secrets from .env.local, then connect to Supabase before the app
  // runs so the client is ready for any query later on.
  await Env.load();
  await initSupabase();

  // Local storage for offline-first routing (logged-in state + onboarding),
  // then reconcile with any Supabase session restored from a previous run.
  await AppPrefs.init();
  await UserSession.instance.restore();

  // Pre-load the splash video BEFORE the first frame is drawn. While this
  // awaits, no Flutter frame is rendered, so the native splash stays on screen.
  // Once ready, the first frame shows the video already playing, so there is
  // no green gap/delay between the native splash and the video.
  final splashController = VideoPlayerController.asset(
    'public/assets/splash/splashscreen.mp4',
  );
  await splashController.initialize();
  await splashController.setVolume(1.0);

  // Warm up the bus Lottie in the background while the splash video plays, so
  // it is already decoded when we transition into the login screen (no jank).
  BusAnimation.preload();

  runApp(MyApp(splashController: splashController));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.splashController});

  final VideoPlayerController splashController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proximity',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: SplashScreen(
        controller: splashController,
        // Once the splash video finishes, check connectivity first: no
        // internet -> network error screen; otherwise route by local state
        // (logged in -> home, else -> login).
        onFinished: () async {
          final online = await NetworkService.instance.hasConnection();
          navigatorKey.currentState?.pushReplacement(
            ScreenTransitions.fade(
              online ? AppRouter.afterSplash() : const NetworkErrorScreen(),
            ),
          );
        },
      ),
    );
  }
}

/// Global navigator key so the splash can trigger navigation once its
/// video finishes playing.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
