import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/animations/screen_transitions.dart';
import '../../../../../core/shared_prefs/shared_prefs.dart';
import '../../../../../core/supabase/supabase_client.dart';
import '../../../../../core/theme/app_colors.dart';
import 'alarm_card/alarm_sound_card.dart';
import 'alarm_mode/alarm_screen.dart';
import 'profile_avatar_service.dart';

/// Settings screen replicating the green-accented card-based design.
/// Uses the existing [AppColors] palette for all colors.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  // ── Derived palette from AppColors ─────────────────────────────────────
  static const Color _bg = AppColors.white;
  static const Color _card = AppColors.white;
  static const Color _ink = AppColors.textDark;
  static const Color _inkSoft = AppColors.textGrey;
  static const Color _accent = AppColors.primary;
  static const Color _line = AppColors.border;
  static const Color _trackOff = Color(0xFFE4E6E1);

  static const double _radiusLg = 22;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _avatarUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final url = await ProfileAvatarService.instance.fetchAvatarUrl();
    if (mounted) setState(() => _avatarUrl = url);
  }

  Future<void> _onAvatarTap() async {
    if (_uploading) return;
    setState(() => _uploading = true);

    try {
      final url =
          await ProfileAvatarService.instance.pickCropAndUploadAvatar(context);
      if (url != null && mounted) {
        setState(() => _avatarUrl = url);
      }
    } catch (_) {
      // Silently fail — the user can retry by tapping again.
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final meta = user?.userMetadata;
    final firstName = meta?['first_name'] as String? ?? '';
    final lastName = meta?['last_name'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = user?.email ?? '';
    final createdAt = user?.createdAt;
    final joinedLabel = createdAt != null
        ? 'JOINED ${_formatDate(DateTime.parse(createdAt))}'
        : '';
    final initials = _getInitials(firstName, lastName);

    return Scaffold(
      backgroundColor: SettingsScreen._bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                  icon: Icons.graphic_eq_rounded,
                  label: 'Alarm mode',
                  sub: _alarmModeLabel(AppPrefs.alarmMode),
                  onTap: () async {
                    await Navigator.of(context).push(
                      ScreenTransitions.fadeRightToLeft(const AlarmScreen()),
                    );
                    if (mounted) setState(() {});
                  },
                ),
                _ChevronRow(
                  icon: Icons.my_location_rounded,
                  label: 'Alert zone distances',
                  sub: '400m · 200m · 50m',
                ),
                _ChevronRow(
                  icon: Icons.swipe_right_rounded,
                  label: 'Dismiss method',
                  sub: 'Swipe to dismiss',
                ),
                _ChevronRow(
                  icon: Icons.vibration_rounded,
                  label: 'Vibration intensity',
                  sub: 'Medium',
                ),
              ],
            ),
            const SizedBox(height: 24),
            // ── Notifications section ────────────────────────────────────
            const _SectionTitle(title: 'Notifications'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _ToggleRow(label: 'Disable all notifications', isOn: false),
                _ToggleRow(label: 'Alarm notification', isOn: true),
                _ToggleRow(label: 'ETA + distance notification', isOn: true),
                _ToggleRow(label: 'Battery optimization', isOn: true),
              ],
            ),
            const SizedBox(height: 24),
            // ── Permissions section ──────────────────────────────────────
            const _SectionTitle(title: 'Permissions'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _ToggleRow(
                    label: 'Location',
                    sub: 'Foreground & background',
                    isOn: true),
                _ToggleRow(label: 'Notifications', isOn: true),
                _ToggleRow(label: 'Alarm', isOn: true),
                _ToggleRow(
                    label: 'Fullscreen',
                    sub: 'Displaying over apps',
                    isOn: true),
                _ToggleRow(
                    label: 'Battery optimization exemption', isOn: true),
                _ToggleRow(label: 'Microphone', isOn: true),
                _ToggleRow(
                    label: 'Photo library', sub: 'Camera access', isOn: true),
              ],
            ),
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getInitials(String first, String last) {
    final f = first.isNotEmpty ? first[0].toUpperCase() : '';
    final l = last.isNotEmpty ? last[0].toUpperCase() : '';
    if (f.isEmpty && l.isEmpty) return 'U';
    return '$f$l';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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

  /// Maps alarm mode keys to human-readable labels.
  String _alarmModeLabel(String key) {
    const labels = {
      'push_notification': 'Push Notification',
      'fullscreen': 'Fullscreen',
    };
    return labels[key] ?? 'Push Notification';
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
                                  placeholder: (_, __) => Container(
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
                                  errorWidget: (_, __, ___) =>
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
                        border: Border.all(
                          color: AppColors.white,
                          width: 2,
                        ),
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
        Expanded(
          child: Container(
            height: 1,
            color: SettingsScreen._line,
          ),
        ),
      ],
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
                      color: Color(0xFFF0F2EE),
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
                border: Border.all(
                  color: SettingsScreen._accent,
                  width: 1.5,
                ),
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

class _ToggleRow extends StatefulWidget {
  const _ToggleRow({
    required this.label,
    this.sub,
    required this.isOn,
  });

  final String label;
  final String? sub;
  final bool isOn;

  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.isOn;
  }

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
                  widget.label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: SettingsScreen._ink,
                  ),
                ),
                if (widget.sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.sub!,
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
          // Custom toggle
          GestureDetector(
            onTap: () => setState(() => _value = !_value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: _value ? AppColors.primary : SettingsScreen._trackOff,
              ),
              padding: const EdgeInsets.all(3),
              alignment:
                  _value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white,
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
