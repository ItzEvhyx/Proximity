import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:video_player/video_player.dart';

import 'core/animations/screen_transitions.dart';
import 'core/config/env.dart';
import 'core/database/app_database.dart';
import 'core/database/settings_sync.dart';
import 'core/global_services/cloudinary_services.dart';
import 'core/global_services/foreground_service.dart';
import 'core/network/network_service.dart';
import 'core/overlay/overlay_service.dart';
import 'core/overlay/overlay_widget.dart';
import 'core/router/app_router.dart';
import 'core/session/user_session.dart';
import 'core/shared_prefs/shared_prefs.dart';
import 'core/firebase/firebase_client.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/login/login_screen.dart';
import 'features/network_error/network_error_screen.dart';
import 'features/splashscreen/splashscreen.dart';

/// Overlay entry point — called by flutter_overlay_window when the system
/// overlay is shown. Must be top-level and annotated with @pragma.
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ProximityOverlayCard(),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlay);

  // Initialize port for communication between foreground task and main isolate.
  FlutterForegroundTask.initCommunicationPort();

  // Do not await plugin or asset work here. An error while reading a local
  // config file used to leave Android's native splash on screen indefinitely.
  runApp(const ProximityApp());
}

/// Root widget that performs async initialization while showing a plain
/// colored screen (matching the native splash). Once ready it hands off to the
/// splash video screen.
class ProximityApp extends StatefulWidget {
  const ProximityApp({super.key});

  @override
  State<ProximityApp> createState() => _ProximityAppState();
}

class _ProximityAppState extends State<ProximityApp> {
  late final Future<VideoPlayerController?> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _bootstrap();
  }

  /// Runs all heavy initialization that used to live in main(). Because the
  /// widget tree is already mounted, Flutter has rendered a first frame and
  /// the OS won't consider the app stuck.
  Future<VideoPlayerController?> _bootstrap() async {
    // Preferences are required for the initial route, but do not let an
    // optional service, permission prompt, or video decoder hold up launch.
    await AppPrefs.init();

    // .env.local is optional at runtime. Cloudinary has a delivery fallback
    // and Mapbox is skipped when no token is configured.
    try {
      await Env.load();
    } catch (_) {
      // A missing or malformed local environment file must not strand users
      // on the launch screen.
    }

    // Cloudinary URL helper (sync, cheap).
    CloudinaryService.instance.init();

    // Initialize foreground service (lightweight, just sets options).
    ProximityForegroundService.instance.init();

    // Start listening for overlay messages (e.g. 'overlay_ready', 'open_app').
    OverlayService.instance.startListening();

    // Mapbox access token — skip gracefully if not configured.
    final mapboxToken = Env.mapboxPublicTokenOrNull;
    if (mapboxToken != null) {
      MapboxOptions.setAccessToken(mapboxToken);
    }

    final splashController = VideoPlayerController.asset(
      'public/assets/splash/splashscreen.mp4',
    );

    // Auth is required by the first interactive screen. Initializing it here
    // removes a race where LoginScreen could be shown before Firebase had a
    // default app, while the first Flutter frame still appears immediately.
    try {
      await initFirebase().timeout(const Duration(seconds: 5));
      await UserSession.instance.restore();
    } catch (_) {
      // The login screen remains available and will show the real Firebase
      // failure instead of trapping the app at launch.
    }

    // Native permission sheets and their associated Settings activities are
    // deliberately never requested during launch. They are requested only
    // when the user starts the feature that needs them.
    unawaited(_finishStartup());

    try {
      await splashController.initialize().timeout(const Duration(seconds: 5));
      await splashController.setVolume(1.0);
    } catch (_) {
      // Continue with a lightweight black fallback if the bundled video
      // cannot be decoded on this device.
      splashController.dispose();
      return null;
    }

    // Warm up the bus Lottie in the background while the splash video plays.
    BusAnimation.preload();

    return splashController;
  }

  /// Work that improves the app after it is visible, but must never block the
  /// first route. Every operation is individually guarded so one unavailable
  /// platform service cannot turn into an infinite splash screen.
  Future<void> _finishStartup() async {
    try {
      await AppDatabase.instance.init();
      await SettingsSync.instance.migrateTripsToSqlite();
      await SettingsSync.instance.pushToSqlite();
      if (UserSession.instance.isLoggedIn) {
        unawaited(SettingsSync.instance.pullFromCloud());
      }
    } catch (_) {
      // SQLite is an enhancement; features retain their SharedPreferences
      // defaults if the database is unavailable.
    }

    try {
      await OverlayService.instance.checkPermission();
    } catch (_) {
      // Overlay support is optional.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proximity',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      // A final presentation guard for bitmap assets supplied by Cloudinary
      // or bundled with the app. Native Mapbox styling is configured separately.
      builder: (context, child) => ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: child ?? const SizedBox.shrink(),
      ),
      navigatorKey: navigatorKey,
      home: FutureBuilder<VideoPlayerController?>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            // While initializing, show a plain screen matching the native
            // splash color so the transition is seamless.
            return const Scaffold(backgroundColor: AppColors.bg);
          }

          final controller = snapshot.data;
          return SplashScreen(
            controller: controller,
            onFinished: () async {
              final online = await NetworkService.instance.hasConnection();
              navigatorKey.currentState?.pushReplacement(
                ScreenTransitions.fade(
                  online ? AppRouter.afterSplash() : const NetworkErrorScreen(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Global navigator key so the splash can trigger navigation once its
/// video finishes playing.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
