import 'package:flutter/material.dart';

import '../../../../../../../core/shared_prefs/shared_prefs.dart';
import '../../../../../../../core/supabase/supabase_client.dart';
import '../../../../../../../core/theme/app_colors.dart';

/// Data model for an alarm mode option.
class _AlarmModeOption {
  const _AlarmModeOption({
    required this.key,
    required this.label,
    required this.asset,
    this.isDefault = false,
    this.clampToBottom = true,
  });

  final String key;
  final String label;
  final String asset;
  final bool isDefault;

  /// If true the image is flush with the card bottom; otherwise it's centered
  /// with padding around it.
  final bool clampToBottom;
}

const _defaultKey = 'push_notification';

const _alarmModes = [
  _AlarmModeOption(
    key: 'push_notification',
    label: 'Push Notification Style',
    asset: 'public/assets/images/push_mockup_img.png',
    isDefault: true,
    clampToBottom: true,
  ),
  _AlarmModeOption(
    key: 'fullscreen',
    label: 'Fullscreen Style',
    asset: 'public/assets/images/fullscreen_notif_mockup.png',
    clampToBottom: false,
  ),
];

/// Alarm Mode screen — lets the user pick their preferred alarm style.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  late String _selectedKey;

  /// Starts false — the screen renders empty (just the top bar) on the first
  /// frame so the route transition is buttery smooth. Content fades in once
  /// the screen is fully built and the transition is done.
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    _selectedKey = AppPrefs.alarmMode;

    // Schedule content reveal after the route transition finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      final animation = route?.animation;

      if (animation == null || animation.isCompleted) {
        // No animation or already done (unlikely but safe).
        _revealContent();
      } else {
        animation.addStatusListener(_onRouteAnimationStatus);
      }
    });
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      ModalRoute.of(context)?.animation?.removeStatusListener(_onRouteAnimationStatus);
      _revealContent();
    }
  }

  /// Shows the content after a single extra frame so the compositor isn't
  /// overwhelmed decoding images on the same frame the transition lands.
  void _revealContent() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showContent = true);
    });
  }

  void _onTap(String key) {
    setState(() {
      if (_selectedKey == key) {
        // Deselect → fall back to default.
        _selectedKey = _defaultKey;
      } else {
        _selectedKey = key;
      }
    });
    // Persist selection.
    AppPrefs.setAlarmMode(_selectedKey);
    _saveToDatabase(_selectedKey);
  }

  Future<void> _saveToDatabase(String key) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await supabase
          .from('profiles')
          .update({'alarm_mode': key}).eq('id', userId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top bar card ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 28,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Text(
                      'Alarm Mode',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // ── Alarm mode cards ─────────────────────────────────────────
            Expanded(
              child: AnimatedOpacity(
                opacity: _showContent ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: _showContent
                    ? ListView.separated(
                        padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                        itemCount: _alarmModes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 28),
                        itemBuilder: (_, index) {
                          final mode = _alarmModes[index];
                          final isSelected = mode.key == _selectedKey;
                          return _AlarmModeCard(
                            mode: mode,
                            isSelected: isSelected,
                            onTap: () => _onTap(mode.key),
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlarmModeCard extends StatelessWidget {
  const _AlarmModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final _AlarmModeOption mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row with check icon ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          mode.label,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (mode.isDefault) ...[
                          const SizedBox(width: 6),
                          const Text(
                            '(Default)',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Check icon
                  AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Mockup image ─────────────────────────────────────────────
            if (mode.clampToBottom)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Image.asset(
                  mode.asset,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded || frame != null) return child;
                    return const SizedBox(height: 200);
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      mode.asset,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return const SizedBox(height: 200);
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
