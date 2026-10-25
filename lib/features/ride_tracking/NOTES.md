# Ride tracking implementation notes

- State management follows the app's existing `ChangeNotifier` style. The ride
  controller is a process singleton because Home, Settings, route results, and
  lifecycle recovery all observe the same session.
- Firestore is the remote transit catalogue: `transit_config/current` provides
  the version and `transit_stations` provides station nodes. Startup sync writes
  a validated snapshot to the existing SQLite database. Active rides read only
  SQLite/the bundled seed and never access Firebase or map services.
- The bundled seed contains LRT-1, LRT-2, and MRT-3, including the current
  LRT-1 extension. Straight-line distance × 1.10 is used until optional
  `transit_segments` geometry is populated by trusted Firebase admin tooling.
- Android uses `native_geofence` for terminated-process callbacks,
  `geolocator` for bounded single fixes, `flutter_local_notifications` for
  exact approach alerts, and the existing foreground task for a persistent
  ride notification without continuous polling.
- iOS interfaces remain portable, but v1 permission and reliability work is
  Android-first as required by `IMPLEMENTATION.md`.
