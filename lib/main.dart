import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'core/config/env.dart';
import 'core/database/app_database.dart';
import 'core/database/settings_sync.dart';
import 'core/global_services/cloudinary_services.dart';
import 'core/global_services/foreground_service.dart';
import 'core/overlay/overlay_service.dart';
import 'core/overlay/overlay_widget.dart';
import 'core/router/app_router.dart';
import 'core/session/user_session.dart';
import 'core/shared_prefs/shared_prefs.dart';
import 'core/firebase/firebase_client.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/ride_tracking/data/station_repository.dart';

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

/// Root widget that performs required initialization before showing the first
/// app route. There is no Flutter splash screen or launch-video delay.
class ProximityApp extends StatefulWidget {
  const ProximityApp({super.key});

  @override
  State<ProximityApp> createState() => _ProximityAppState();
}

class _ProximityAppState extends State<ProximityApp> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _bootstrap();
  }

  /// Runs the required initialization after Flutter has mounted its first
  /// frame, so platform setup cannot block the app process at launch.
  Future<void> _bootstrap() async {
    // Preferences are required for the initial route, but do not let an
    // optional service or permission prompt hold up launch.
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
        // Transit data is version-checked once at startup. The repository
        // refuses to touch Firestore while a ride session is active.
        unawaited(StationRepository().syncFromFirebaseIfChanged());
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
      navigatorKey: navigatorKey,
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            // Required state is still loading; keep the first frame plain and
            // immediately move to the real route when it is available.
            return const Scaffold(backgroundColor: AppColors.bg);
          }

          return AppRouter.afterSplash();
        },
      ),
    );
  }
}

/// Global navigator key used by features that navigate outside a widget tree.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
