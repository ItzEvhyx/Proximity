import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/animations/screen_transitions.dart';
import '../../../../../core/global_services/foreground_service.dart';
import '../../../../../core/overlay/overlay_service.dart';
import '../../../../../core/permissions/app_permission_service.dart';
import '../../../../../core/shared_prefs/shared_prefs.dart';
import '../../../../../core/firebase/firebase_client.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../ride_tracking/presentation/ride_widgets.dart';
import '../../../../ride_tracking/ride_controller.dart';
import 'alarm_settings/alarm_card/alarm_dismissal.dart';
import 'alarm_settings/alarm_card/alarm_sound_card.dart';
import 'alarm_settings/alarm_card/alarm_vibration.dart';
import 'alarm_settings/alarm_card/alert_zone_card.dart';
import 'profile_avatar_service.dart';

/// Settings screen using the app-wide monochrome card system.
/// Uses the existing [AppColors] palette for all colors.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.active = false, this.onLogout});

  final bool active;
  final Future<void> Function()? onLogout;

  // ── Derived palette from AppColors ─────────────────────────────────────
  static const Color _bg = AppColors.bg;
  static const Color _card = AppColors.surfaceRaised;
  static const Color _ink = AppColors.textPrimary;
  static const Color _inkSoft = AppColors.textSecondary;
  static const Color _accent = AppColors.textPrimary;
  static const Color _line = AppColors.border;
  static const Color _trackOff = AppColors.surfaceHigh;

  static const double _radiusLg = 22;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  String? _avatarUrl;
  bool _uploading = false;
  Map<AppPermission, AppPermissionState> _permissionStates = const {};
  bool _initialLoadScheduled = false;

  /// When false, the screen body is replaced by an empty container so the
  /// navigation transition doesn't need to composite the full widget tree.
  bool _contentVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleInitialLoad();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleInitialLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) {
      _loadPermissionStates();
    }
  }

  /// Firebase/profile image and permission-platform calls are deliberately
  /// delayed until the tab slide finishes. Starting all of them in the first
  /// Settings frame was the main source of the first-visit hitch.
  void _scheduleInitialLoad() {
    if (!widget.active ||
        _initialLoadScheduled ||
        _permissionStates.isNotEmpty) {
      return;
    }
    _initialLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 340));
      if (!mounted || !widget.active) {
        _initialLoadScheduled = false;
        return;
      }
      _loadAvatar();
      _loadPermissionStates();
    });
  }

  Future<void> _loadPermissionStates() async {
    final entries = await Future.wait(
      AppPermission.values.map(
        (permission) async => MapEntry(
          permission,
          await AppPermissionService.instance.stateFor(permission),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _permissionStates = Map.fromEntries(entries));
  }

  Future<void> _setPermissionUsage(
    AppPermission permission,
    bool enabled,
  ) async {
    await AppPermissionService.instance.setAppEnabled(permission, enabled);
    if (!enabled) {
      switch (permission) {
        case AppPermission.location:
          await RideController.instance.disable();
          await ProximityForegroundService.instance.stop();
          break;
        case AppPermission.overlay:
          await OverlayService.instance.hide();
          break;
        case AppPermission.notifications:
          // A foreground service is required to display an Android tracking
          // notification, so end active tracking instead of leaving a stale
          // notification visible after the user opts out.
          await RideController.instance.disable();
          await ProximityForegroundService.instance.stop();
          break;
        case AppPermission.exactAlarm:
        case AppPermission.batteryOptimization:
        case AppPermission.microphone:
        case AppPermission.photoLibrary:
          break;
      }
    }
    await _loadPermissionStates();
  }

  Future<void> _loadAvatar() async {
    final url = await ProfileAvatarService.instance.fetchAvatarUrl();
    if (mounted) setState(() => _avatarUrl = url);
  }

  Future<void> _onAvatarTap() async {
    if (_uploading) return;
    setState(() => _uploading = true);

    try {
      final url = await ProfileAvatarService.instance.pickCropAndUploadAvatar(
        context,
      );
      if (url != null && mounted) {
        setState(() => _avatarUrl = url);
      }
    } catch (_) {
      // Silently fail — the user can retry by tapping again.
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Pushes a route while hiding this screen's content to keep the transition
  /// smooth (GPU only composites a blank scaffold during the slide).
  Future<T?> _pushRoute<T>(Route<T> route) async {
    setState(() => _contentVisible = false);
    // Wait one frame so the empty scaffold is actually rendered before the
    // navigator starts the push transition.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;
    final result = await Navigator.of(context).push(route);
    if (mounted) setState(() => _contentVisible = true);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final user = firebaseAuth.currentUser;
    final nameParts = (user?.displayName ?? '').trim().split(RegExp(r'\s+'));
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    final fullName = user?.displayName ?? '';
    final email = user?.email ?? '';
    final createdAt = user?.metadata.creationTime;
    final joinedLabel = createdAt != null
        ? 'JOINED ${_formatDate(createdAt)}'
        : '';
    final initials = _getInitials(firstName, lastName);

    return Scaffold(
      backgroundColor: SettingsScreen._bg,
      body: SafeArea(
        child: _contentVisible
            ? RepaintBoundary(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  children: [
                    const SizedBox(height: 14),
                    // ── Header ───────────────────────────────────────────────────
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: SettingsScreen._ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Profile card ─────────────────────────────────────────────
                    _ProfileCard(
                      name: fullName.isNotEmpty ? fullName : 'User',
                      email: email,
                      joined: joinedLabel,
                      initials: initials,
                      avatarUrl: _avatarUrl,
                      uploading: _uploading,
                      onAvatarTap: _onAvatarTap,
                    ),
                    const SizedBox(height: 26),
                    // ── Alarm section ────────────────────────────────────────────
                    const _SectionTitle(title: 'Alarm'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      showRail: true,
                      children: [
                        _ChevronRow(
                          icon: Icons.alarm_rounded,
                          label: 'Alarm sound',
                          sub: _alarmSoundLabel(AppPrefs.alarmSound),
                          onTap: () async {
                            await showAlarmSoundPicker(context);
                            if (mounted) setState(() {});
                          },
                        ),
                        _ChevronRow(
                          icon: Icons.my_location_rounded,
                          label: 'Alert zone distances',
                          sub: _alertZoneLabel(),
                          onTap: () async {
                            await showAlertZonePicker(context);
                            if (mounted) setState(() {});
                          },
                        ),
                        _ChevronRow(
                          icon: Icons.swipe_right_rounded,
                          label: 'Dismiss method',
                          sub: _dismissMethodLabel(AppPrefs.dismissMethod),
                          onTap: () async {
                            await _pushRoute(
                              ScreenTransitions.fadeRightToLeft(
                                const DismissMethodScreen(),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                        ),
                        _ChevronRow(
                          icon: Icons.vibration_rounded,
                          label: 'Vibration intensity',
                          sub: _vibrationLabel(AppPrefs.vibrationIntensity),
                          onTap: () async {
                            await showVibrationPicker(context);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const RideSettingsSection(),
                    const SizedBox(height: 24),
                    // ── Notifications section ────────────────────────────────────
                    const _SectionTitle(title: 'Notifications'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: [
                        _ToggleRow(
                          label: 'Disable all notifications',
                          isOn: false,
                        ),
                        _ToggleRow(label: 'Alarm notification', isOn: true),
                        _ToggleRow(
                          label: 'ETA + distance notification',
                          isOn: true,
                        ),
                        _ToggleRow(label: 'Battery optimization', isOn: true),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // ── Permissions section ──────────────────────────────────────
                    const _SectionTitle(title: 'Permissions'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: [
                        _permissionRow(AppPermission.location, 'Location'),
                        _permissionRow(
                          AppPermission.notifications,
                          'Notifications',
                        ),
                        _permissionRow(AppPermission.exactAlarm, 'Alarm'),
                        _permissionRow(
                          AppPermission.overlay,
                          'Fullscreen',
                          fallbackSub: 'Displaying over apps',
                        ),
                        _permissionRow(
                          AppPermission.batteryOptimization,
                          'Battery optimization exemption',
                        ),
                        _permissionRow(AppPermission.microphone, 'Microphone'),
                        _permissionRow(
                          AppPermission.photoLibrary,
                          'Photo library',
                        ),
                      ],
                    ),
                    if (_permissionStates.values.any(
                      (state) => !state.systemGranted,
                    )) ...[
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Enable a permission from the feature that needs it before you can toggle its app access.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: SettingsScreen._inkSoft,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // ── About section ────────────────────────────────────────────
                    const _SectionTitle(title: 'About'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      showRail: true,
                      children: [
                        _ChevronRow(
                          icon: Icons.info_outline_rounded,
                          label: 'App version',
                          sub: '1.0.0',
                        ),
                        _ChevronRow(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Send feedback',
                        ),
                        _ChevronRow(
                          icon: Icons.shield_outlined,
                          label: 'Privacy policy / terms',
                        ),
                        _ChevronRow(
                          icon: Icons.star_outline_rounded,
                          label: 'Rate the app',
                        ),
                      ],
                    ),
                    if (widget.onLogout != null) ...[
                      const SizedBox(height: 24),
                      _LogoutButton(onTap: widget.onLogout!),
                    ],
                    // Keep the action clear of the persistent bottom bar.
                    const SizedBox(height: 120),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  String _getInitials(String first, String last) {
    final f = first.isNotEmpty ? first[0].toUpperCase() : '';
    final l = last.isNotEmpty ? last[0].toUpperCase() : '';
    if (f.isEmpty && l.isEmpty) return 'U';
    return '$f$l';
  }

  Widget _permissionRow(
    AppPermission permission,
    String label, {
    String? fallbackSub,
  }) {
    final state = _permissionStates[permission];
    final isGranted = state?.systemGranted ?? false;
    final sub = !isGranted
        ? 'Enable permission first to toggle'
        : !(state?.appEnabled ?? false)
        ? 'Off — Proximity will not use this permission'
        : (state?.detail ?? fallbackSub);
    return _ToggleRow(
      label: label,
      sub: sub,
      isOn: state?.appEnabled ?? false,
      enabled: isGranted,
      onChanged: (value) => _setPermissionUsage(permission, value),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Maps alarm sound keys to human-readable labels.
  String _alarmSoundLabel(String key) {
    const labels = {
      'default_alarm': 'Default Alarm',
      'birds_chirping': 'Birds Chirping',
      'life_core': 'Life Core',
      'piano': 'Piano',
      'air_raid': 'Air Raid',
      'alarm_clock': 'Alarm Clock',
      'loud_alarm': 'Loud Alarm',
    };
    return labels[key] ?? 'Default Alarm';
  }

  /// Builds the subtitle for alert zone distances (e.g. '400m · 200m · 50m').
  String _alertZoneLabel() {
    final distances = AppPrefs.alertZoneDistances;
    final unit = AppPrefs.alertZoneUnit;
    return distances
        .map((d) {
          if (unit == 'km') {
            final km = d / 1000;
            return km == km.toInt()
                ? '${km.toInt()}km'
                : '${km.toStringAsFixed(1)}km';
          }
          return '${d}m';
        })
        .join(' · ');
  }

  /// Maps dismiss method keys to human-readable labels.
  String _dismissMethodLabel(String key) {
    const labels = {
      'slide': 'Slide to snooze',
      'shake': 'Shake to snooze',
      'solve': 'Solve to snooze',
    };
    return labels[key] ?? 'Slide to snooze';
  }

  /// Maps vibration intensity keys to human-readable labels.
  String _vibrationLabel(String key) {
    const labels = {
      'off': 'Off',
      'light': 'Light',
      'medium': 'Medium',
      'strong': 'Strong',
    };
    return labels[key] ?? 'Medium';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.joined,
    required this.initials,
    required this.avatarUrl,
    required this.uploading,
    required this.onAvatarTap,
  });

  final String name;
  final String email;
  final String joined;
  final String initials;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SettingsScreen._card,
        borderRadius: BorderRadius.circular(SettingsScreen._radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Tappable avatar
          GestureDetector(
            onTap: onAvatarTap,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The avatar image or placeholder
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: uploading
                          ? Container(
                              color: AppColors.surfaceMuted,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            )
                          : avatarUrl != null
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl!,
                              width: 62,
                              height: 62,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                color: AppColors.surfaceMuted,
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (_, _, _) =>
                                  _defaultAvatar(initials),
                            )
                          : _defaultAvatar(initials),
                    ),
                  ),
                  // Camera badge at bottom-right
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 12,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: SettingsScreen._ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    color: SettingsScreen._inkSoft,
                  ),
                ),
                if (joined.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    joined,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      color: SettingsScreen._inkSoft.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Default avatar when no image is set — shows the user's initials in a
  /// green gradient circle, matching the original design.
  Widget _defaultAvatar(String initials) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.35),
            AppColors.primary.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.6,
            color: SettingsScreen._inkSoft,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: SettingsScreen._line)),
      ],
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
              SizedBox(width: 10),
              Text(
                'Log out',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children, this.showRail = false});

  final List<Widget> children;
  final bool showRail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SettingsScreen._card,
        borderRadius: BorderRadius.circular(SettingsScreen._radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Dashed rail on the left (for icon-chip sections)
          if (showRail)
            Positioned(
              left: 34,
              top: 34,
              bottom: 34,
              child: CustomPaint(
                size: const Size(1, double.infinity),
                painter: _DashedLinePainter(color: SettingsScreen._line),
              ),
            ),
          // Rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.surfaceHigh,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChevronRow extends StatelessWidget {
  const _ChevronRow({
    required this.icon,
    required this.label,
    this.sub,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Icon with green border, card-colored background
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SettingsScreen._card,
                border: Border.all(color: SettingsScreen._accent, width: 1.5),
              ),
              child: Icon(icon, size: 16, color: SettingsScreen._accent),
            ),
            const SizedBox(width: 14),
            // Label + sub
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: SettingsScreen._ink,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        color: SettingsScreen._inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: SettingsScreen._inkSoft.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    this.sub,
    required this.isOn,
    this.enabled = true,
    this.onChanged,
  });

  final String label;
  final String? sub;
  final bool isOn;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: enabled
                        ? SettingsScreen._ink
                        : SettingsScreen._inkSoft.withValues(alpha: 0.65),
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      color: enabled
                          ? SettingsScreen._inkSoft
                          : SettingsScreen._inkSoft.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Custom toggle
          GestureDetector(
            onTap: enabled ? () => onChanged?.call(!isOn) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isOn && enabled
                    ? AppColors.primary
                    : SettingsScreen._trackOff,
              ),
              padding: const EdgeInsets.all(3),
              alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled
                      ? AppColors.white
                      : AppColors.white.withValues(alpha: 0.45),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a vertical dashed line for the card rail.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashHeight = 5.0;
    const gapHeight = 4.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dashHeight), paint);
      y += dashHeight + gapHeight;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}
