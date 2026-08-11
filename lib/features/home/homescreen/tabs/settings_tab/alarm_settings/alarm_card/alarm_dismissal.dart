import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../../../../core/global_services/vibration_service.dart';
import '../../../../../../../core/shared_prefs/shared_prefs.dart';
import '../../../../../../../core/supabase/supabase_client.dart';
import '../../../../../../../core/theme/app_colors.dart';

// ── Alarm sound key → asset path mapping ─────────────────────────────────────

const _soundAssets = {
  'default_alarm': 'public/assets/audio/default_alarm.mp3',
  'birds_chirping': 'public/assets/audio/calming alarms/birds_chirping_alarm.mp3',
  'life_core': 'public/assets/audio/calming alarms/life_core_alarm.mp3',
  'piano': 'public/assets/audio/calming alarms/piano_alarm.mp3',
  'air_raid': 'public/assets/audio/intense alarms/air_raid_salarm.mp3',
  'alarm_clock': 'public/assets/audio/intense alarms/alarm_clock_tone.mp3',
  'loud_alarm': 'public/assets/audio/intense alarms/loud_alarm.mp3',
};

const _defaultKey = 'slide';

/// Dismiss Method screen — interactive preview of each dismiss style.
class DismissMethodScreen extends StatefulWidget {
  const DismissMethodScreen({super.key});

  @override
  State<DismissMethodScreen> createState() => _DismissMethodScreenState();
}

class _DismissMethodScreenState extends State<DismissMethodScreen> {
  late String _selectedKey;
  bool _showContent = false;
  final AudioPlayer _player = AudioPlayer();
  bool _alarmPlaying = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _selectedKey = AppPrefs.dismissMethod;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      final animation = route?.animation;
      if (animation == null || animation.isCompleted) {
        _revealContent();
      } else {
        animation.addStatusListener(_onRouteAnimationStatus);
      }
    });
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && _alarmPlaying) {
            _player.seek(Duration.zero);
            _player.play();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    VibrationService.instance.stop();
    super.dispose();
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      ModalRoute.of(context)
          ?.animation
          ?.removeStatusListener(_onRouteAnimationStatus);
      _revealContent();
    }
  }

  void _revealContent() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showContent = true);
    });
  }

  void _onCardTap(String key) {
    if (_alarmPlaying && _selectedKey == key) return;
    setState(() {
      _selectedKey = key;
      _dismissed = false;
    });
    // Instantly persist the new dismiss method so it takes effect immediately.
    AppPrefs.setDismissMethod(key);
    _saveToDatabase(key);
    _startAlarm();
  }

  Future<void> _startAlarm() async {
    final soundKey = AppPrefs.alarmSound;
    final asset = _soundAssets[soundKey] ?? _soundAssets['default_alarm']!;
    try {
      await _player.stop();
      await _player.setAsset(asset);
      // Fire both at the exact same moment.
      _player.play();
      VibrationService.instance.start();
      if (mounted) setState(() => _alarmPlaying = true);
    } catch (_) {}
  }

  void _onDismissed() {
    _player.stop();
    VibrationService.instance.stop();
    if (mounted) {
      setState(() {
        _alarmPlaying = false;
        _dismissed = true;
      });
    }
  }

  Future<void> _save() async {
    // Already saved on card tap — just navigate back.
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveToDatabase(String key) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await supabase
          .from('profiles')
          .update({'dismiss_method': key}).eq('id', userId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
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
                            child: Icon(Icons.chevron_left_rounded,
                                size: 28, color: AppColors.primary),
                          ),
                        ),
                        const Text('Dismiss Method',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: AnimatedOpacity(
                    opacity: _showContent ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: _showContent
                        ? ListView(
                            padding: const EdgeInsets.fromLTRB(32, 0, 32, 100),
                            children: [
                              _buildCard(
                                  key: 'slide',
                                  label: 'Slide to snooze',
                                  isDefault: true,
                                  child: _SlideWidget(
                                      active: _selectedKey == 'slide' &&
                                          _alarmPlaying,
                                      onDismissed: _onDismissed)),
                              const SizedBox(height: 28),
                              _buildCard(
                                  key: 'shake',
                                  label: 'Shake to Snooze',
                                  child: _ShakeWidget(
                                      active: _selectedKey == 'shake' &&
                                          _alarmPlaying,
                                      onDismissed: _onDismissed)),
                              const SizedBox(height: 28),
                              _buildCard(
                                  key: 'solve',
                                  label: 'Solve to snooze',
                                  child: _SolveWidget(
                                      active: _selectedKey == 'solve' &&
                                          _alarmPlaying,
                                      onDismissed: _onDismissed)),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            // Save button
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              bottom: _dismissed
                  ? MediaQuery.paddingOf(context).bottom + 24
                  : -80,
              left: 32,
              right: 32,
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('Save',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String key,
    required String label,
    required Widget child,
    bool isDefault = false,
  }) {
    final isSelected = key == _selectedKey;
    return GestureDetector(
      onTap: () => _onCardTap(key),
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
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(children: [
                      Text(label,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                      if (isDefault) ...[
                        const SizedBox(width: 6),
                        const Text('(Default)',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textGrey)),
                      ],
                    ]),
                  ),
                  AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 24, height: 24,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.primary),
                      child: const Icon(Icons.check_rounded,
                          size: 14, color: AppColors.white),
                    ),
                  ),
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SLIDE TO SNOOZE
// ═══════════════════════════════════════════════════════════════════════════════

class _SlideWidget extends StatefulWidget {
  const _SlideWidget({required this.active, required this.onDismissed});
  final bool active;
  final VoidCallback onDismissed;
  @override
  State<_SlideWidget> createState() => _SlideWidgetState();
}

class _SlideWidgetState extends State<_SlideWidget> {
  double _dragX = 0;
  double _maxDrag = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          const thumbWidth = 80.0;
          const thumbHeight = 44.0;
          _maxDrag = trackWidth - thumbWidth - 8;

          return Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(left: 50),
                    child: Text('Slide to snooze',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70)),
                  ),
                ),
                Positioned(
                  left: 4 + _dragX,
                  child: GestureDetector(
                    onHorizontalDragUpdate: widget.active
                        ? (d) => setState(() => _dragX =
                            (_dragX + d.delta.dx).clamp(0.0, _maxDrag))
                        : null,
                    onHorizontalDragEnd: widget.active
                        ? (_) {
                            if (_dragX >= _maxDrag * 0.85) {
                              widget.onDismissed();
                            }
                            setState(() => _dragX = 0);
                          }
                        : null,
                    child: Container(
                      width: thumbWidth,
                      height: thumbHeight,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Center(
                        child: Icon(Icons.double_arrow_rounded,
                            color: AppColors.primary, size: 24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHAKE TO SNOOZE — modern design with pulsing rings and phone animation
// ═══════════════════════════════════════════════════════════════════════════════

class _ShakeWidget extends StatefulWidget {
  const _ShakeWidget({required this.active, required this.onDismissed});
  final bool active;
  final VoidCallback onDismissed;
  @override
  State<_ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with TickerProviderStateMixin {
  StreamSubscription? _accelSub;
  int _shakeCount = 0;
  static const _shakeThreshold = 15.0;
  static const _requiredShakes = 5;
  DateTime _lastShake = DateTime(2000);

  late final AnimationController _pulseController;
  late final AnimationController _shakeAnimController;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _shakeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -0.15), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.12), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.12, end: -0.08), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.06), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: 0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),
    ]).animate(_shakeAnimController);
  }

  @override
  void didUpdateWidget(covariant _ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _startListening();
      _pulseController.repeat();
      _shakeAnimController.repeat();
    } else if (!widget.active && oldWidget.active) {
      _stopListening();
      _pulseController.stop();
      _shakeAnimController.stop();
    }
  }

  void _startListening() {
    _shakeCount = 0;
    _accelSub = accelerometerEventStream().listen((event) {
      final mag = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z);
      if (mag > _shakeThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastShake).inMilliseconds > 300) {
          _lastShake = now;
          _shakeCount++;
          if (mounted) setState(() {});
          if (_shakeCount >= _requiredShakes) {
            _stopListening();
            _pulseController.stop();
            _shakeAnimController.stop();
            widget.onDismissed();
          }
        }
      }
    });
  }

  void _stopListening() {
    _accelSub?.cancel();
    _accelSub = null;
  }

  @override
  void dispose() {
    _stopListening();
    _pulseController.dispose();
    _shakeAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_shakeCount / _requiredShakes).clamp(0.0, 1.0);
    final isArmed = widget.active;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // ── Stage: rings + phone + wave bars ────────────────────────
          SizedBox(
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing rings
                if (isArmed)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) => Stack(
                      alignment: Alignment.center,
                      children: [
                        _PulseRing(progress: _pulseController.value),
                        _PulseRing(
                            progress:
                                (_pulseController.value + 0.33) % 1.0),
                        _PulseRing(
                            progress:
                                (_pulseController.value + 0.66) % 1.0),
                      ],
                    ),
                  ),
                // Wave bars left
                Positioned(
                  left: 16,
                  child: _WaveBars(active: isArmed),
                ),
                // Wave bars right
                Positioned(
                  right: 16,
                  child: _WaveBars(active: isArmed),
                ),
                // Phone icon
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (context, child) => Transform.rotate(
                    angle: isArmed ? _shakeAnim.value : 0,
                    child: child,
                  ),
                  child: Container(
                    width: 48,
                    height: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFBFCFB), Color(0xFFEEF1EC)],
                      ),
                      border: Border.all(
                        color: isArmed
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.7),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Caption
          Text(
            isArmed
                ? 'Listening for shake…'
                : 'Tap card to arm sensor',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isArmed ? AppColors.primary : AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 14),
          // Progress track
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor:
                  AppColors.primary.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          // Meta row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArmed ? 'Armed' : 'Ready',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.textGrey,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                '$_shakeCount / $_requiredShakes shakes',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single expanding/fading ring for the pulse animation.
class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final size = 60 + progress * 80;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: (1 - progress) * 0.5),
          width: 1,
        ),
      ),
    );
  }
}

/// Animated vertical wave bars on either side of the phone.
class _WaveBars extends StatefulWidget {
  const _WaveBars({required this.active});
  final bool active;
  @override
  State<_WaveBars> createState() => _WaveBarsState();
}

class _WaveBarsState extends State<_WaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void didUpdateWidget(covariant _WaveBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.active) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppColors.primary : AppColors.border;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bar(color, 6 + t * 6),
            const SizedBox(width: 3),
            _bar(color, 16 - t * 8),
            const SizedBox(width: 3),
            _bar(color, 10 + t * 4),
          ],
        );
      },
    );
  }

  Widget _bar(Color color, double height) {
    return Container(
      width: 3.5,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SOLVE TO SNOOZE — with shake animation on wrong answer
// ═══════════════════════════════════════════════════════════════════════════════

class _SolveWidget extends StatefulWidget {
  const _SolveWidget({required this.active, required this.onDismissed});
  final bool active;
  final VoidCallback onDismissed;
  @override
  State<_SolveWidget> createState() => _SolveWidgetState();
}

class _SolveWidgetState extends State<_SolveWidget>
    with SingleTickerProviderStateMixin {
  late int _numA;
  late int _numB;
  late String _operator;
  late int _answer;
  final _controller = TextEditingController();
  bool _wrong = false;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeOffset;

  @override
  void initState() {
    super.initState();
    _generatePuzzle();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));
  }

  void _generatePuzzle() {
    final rng = Random();
    final ops = ['+', '−', '×', '÷'];
    _operator = ops[rng.nextInt(ops.length)];
    switch (_operator) {
      case '÷':
        _numB = rng.nextInt(9) + 1;
        _answer = rng.nextInt(9) + 1;
        _numA = _numB * _answer;
        break;
      case '×':
        _numA = rng.nextInt(9) + 1;
        _numB = rng.nextInt(9) + 1;
        _answer = _numA * _numB;
        break;
      case '−':
        _numA = rng.nextInt(90) + 10;
        _numB = rng.nextInt(_numA) + 1;
        _answer = _numA - _numB;
        break;
      default:
        _numA = rng.nextInt(50) + 1;
        _numB = rng.nextInt(50) + 1;
        _answer = _numA + _numB;
    }
  }

  void _checkAnswer(String value) {
    final parsed = int.tryParse(value);
    if (parsed == _answer) {
      widget.onDismissed();
    } else if (value.isNotEmpty) {
      setState(() => _wrong = true);
      _shakeCtrl.forward(from: 0);
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() => _wrong = false);
          _controller.clear();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: AnimatedBuilder(
        animation: _shakeOffset,
        builder: (context, child) => Transform.translate(
          offset: Offset(_shakeOffset.value, 0),
          child: child,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NumberBox(value: _numA.toString()),
            const SizedBox(width: 10),
            Text(_operator,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(width: 10),
            _NumberBox(value: _numB.toString()),
            const SizedBox(width: 10),
            const Text('=',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(width: 10),
            SizedBox(
              width: 56,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _wrong ? AppColors.error : AppColors.primary,
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  enabled: widget.active,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: _checkAnswer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded square box displaying a number.
class _NumberBox extends StatelessWidget {
  const _NumberBox({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(value,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
      ),
    );
  }
}
