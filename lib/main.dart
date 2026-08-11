import 'package:flutter/material.dart';
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
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_colors.dart';
import 'features/login/login_screen.dart';
import 'features/network_error/network_error_screen.dart';
import 'features/splashscreen/splashscreen.dart';

/// Overlay entry point — called by flutter_overlay_window when the system
/// overlay is shown. Must be top-level and annotated with @pragma.
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ProximityOverlayCard(),
  ));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize port for communication between foreground task and main isolate.
  FlutterForegroundTask.initCommunicationPort();

  // Only load the lightweight env file before runApp — everything else
  // initializes inside the widget tree so the OS sees a first frame quickly
  // and doesn't kill the process for being unresponsive.
  await Env.load();

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
  late final Future<VideoPlayerController> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _bootstrap();
  }

  /// Runs all heavy initialization that used to live in main(). Because the
  /// widget tree is already mounted, Flutter has rendered a first frame and
  /// the OS won't consider the app stuck.
  Future<VideoPlayerController> _bootstrap() async {
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

    // Supabase, SharedPreferences, and session restore can run in parallel
    // with the video load for faster startup.
    final splashController = VideoPlayerController.asset(
      'public/assets/splash/splashscreen.mp4',
    );

    await Future.wait([
      initSupabase(),
      AppPrefs.init(),
      splashController.initialize(),
      // Request notification permission early so the OS prompt appears once
      // during startup. The user just taps "Allow" and never thinks about it
      // again — no manual settings navigation needed.
      ProximityForegroundService.instance.requestPermissions(),
      // Check overlay permission (doesn't prompt — just caches the status).
      OverlayService.instance.checkPermission(),
    ]);

    // Request "Display over other apps" permission. This opens a settings
    // page on the first run — the user toggles it once and never sees it again.
    // We do this after the other parallel inits so it doesn't block the splash.
    await OverlayService.instance.requestPermission();

    // Restore user session (depends on both Supabase + AppPrefs being ready).
    await UserSession.instance.restore();

    // Initialize SQLite database and run one-time migrations.
    await AppDatabase.instance.init();
    await SettingsSync.instance.migrateTripsToSqlite();
    await SettingsSync.instance.pushToSqlite();

    // If a user is logged in, pull their settings from the cloud so a new
    // device gets the correct preferences without manual reconfiguration.
    if (UserSession.instance.isLoggedIn) {
      // Fire-and-forget — don't block startup on network.
      SettingsSync.instance.pullFromCloud();
    }

    await splashController.setVolume(1.0);

    // Warm up the bus Lottie in the background while the splash video plays.
    BusAnimation.preload();

    return splashController;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proximity',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: FutureBuilder<VideoPlayerController>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              snapshot.hasError) {
            // While initializing, show a plain screen matching the native
            // splash color so the transition is seamless.
            return const Scaffold(backgroundColor: AppColors.primary);
          }

          final controller = snapshot.data!;
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
