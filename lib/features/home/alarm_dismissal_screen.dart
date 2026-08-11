import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/global_services/vibration_service.dart';
import '../../../core/global_services/volume_service.dart';
import '../../../core/shared_prefs/shared_prefs.dart';
import '../../../core/theme/app_colors.dart';

// ── Sound assets (same as dismiss settings) ──────────────────────────────────

const _soundAssets = {
  'default_alarm': 'public/assets/audio/default_alarm.mp3',
  'birds_chirping': 'public/assets/audio/calming alarms/birds_chirping_alarm.mp3',
  'life_core': 'public/assets/audio/calming alarms/life_core_alarm.mp3',
  'piano': 'public/assets/audio/calming alarms/piano_alarm.mp3',
  'air_raid': 'public/assets/audio/intense alarms/air_raid_salarm.mp3',
  'alarm_clock': 'public/assets/audio/intense alarms/alarm_clock_tone.mp3',
  'loud_alarm': 'public/assets/audio/intense alarms/loud_alarm.mp3',
};

/// Fullscreen alarm screen shown when the user enters proximity of their
/// destination. Plays alarm + vibration, shows ETA/distance, and requires
/// the user to perform their chosen dismiss method to stop.
class AlarmDismissalScreen extends StatefulWidget {
  const AlarmDismissalScreen({
    super.key,
    required this.distance,
    required this.eta,
    required this.onDismissed,
  });

  final String distance;
  final String eta;
  final VoidCallback onDismissed;

  @override
  State<AlarmDismissalScreen> createState() => _AlarmDismissalScreenState();
}

class _AlarmDismissalScreenState extends State<AlarmDismissalScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    // Keep screen on while alarm is ringing (prevents display sleep timeout).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startAlarm();
    // Loop playback.
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed &&
          mounted &&
          !_dismissed) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && !_dismissed) {
            _player.seek(Duration.zero);
            _player.play();
          }
        });
      }
    });
  }

  Future<void> _startAlarm() async {
    // Override system volume to maximum so the alarm is always audible.
    await VolumeService.instance.maximizeVolume();

    final soundKey = AppPrefs.alarmSound;
    final asset = _soundAssets[soundKey] ?? _soundAssets['default_alarm']!;
    try {
      await _player.setAsset(asset);
      _player.play();
      VibrationService.instance.start();
    } catch (_) {}
  }

  void _onDismissed() {
    if (_dismissed) return;
    setState(() => _dismissed = true);
    _player.stop();
    VibrationService.instance.stop();
    VolumeService.instance.restoreVolume();
    // Restore normal system UI mode.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    widget.onDismissed();
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    VibrationService.instance.stop();
    VolumeService.instance.restoreVolume();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dismissMethod = AppPrefs.dismissMethod;

    return PopScope(
      canPop: false, // Prevent back button — must dismiss properly.
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // ── Alarm icon ─────────────────────────────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: Image.asset(
                      'public/assets/icons/alarm_icon.png',
                      width: 44,
                      height: 44,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // ── Wake up! ───────────────────────────────────────────────
                const Text(
                  'Wake up!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "You're close to your stop. Grab\nyour things and get ready to hop off.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                // ── Distance + Time Left cards ─────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _InfoPill(label: 'Distance', value: widget.distance),
                    const SizedBox(width: 12),
                    _InfoPill(label: 'Time Left', value: widget.eta),
                  ],
                ),
                const Spacer(flex: 2),
                // ── Dismiss method widget ──────────────────────────────────
                if (dismissMethod == 'slide')
                  _SlideDismiss(onDismissed: _onDismissed)
                else if (dismissMethod == 'shake')
                  _ShakeDismiss(onDismissed: _onDismissed)
                else
                  _SolveDismiss(onDismissed: _onDismissed),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Green-on-dark info pill showing distance or time.
class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SLIDE DISMISS
// ═══════════════════════════════════════════════════════════════════════════════

class _SlideDismiss extends StatefulWidget {
  const _SlideDismiss({required this.onDismissed});
  final VoidCallback onDismissed;
  @override
  State<_SlideDismiss> createState() => _SlideDismissState();
}

class _SlideDismissState extends State<_SlideDismiss> {
  double _dragX = 0;
  double _maxDrag = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        const thumbWidth = 80.0;
        const thumbHeight = 44.0;
        _maxDrag = trackWidth - thumbWidth - 8;

        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 50),
                  child: Text(
                    'Slide to snooze',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 4 + _dragX,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => setState(
                      () => _dragX = (_dragX + d.delta.dx).clamp(0.0, _maxDrag)),
                  onHorizontalDragEnd: (_) {
                    if (_dragX >= _maxDrag * 0.85) {
                      widget.onDismissed();
                    }
                    setState(() => _dragX = 0);
                  },
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHAKE DISMISS
// ═══════════════════════════════════════════════════════════════════════════════

class _ShakeDismiss extends StatefulWidget {
  const _ShakeDismiss({required this.onDismissed});
  final VoidCallback onDismissed;
  @override
  State<_ShakeDismiss> createState() => _ShakeDismissState();
}

class _ShakeDismissState extends State<_ShakeDismiss> {
  StreamSubscription? _accelSub;
  int _shakeCount = 0;
  static const _shakeThreshold = 15.0;
  static const _requiredShakes = 5;
  DateTime _lastShake = DateTime(2000);

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _shakeCount = 0;
    _accelSub = accelerometerEventStream().listen((event) {
      final mag =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (mag > _shakeThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastShake).inMilliseconds > 300) {
          _lastShake = now;
          _shakeCount++;
          if (mounted) setState(() {});
          if (_shakeCount >= _requiredShakes) {
            _stopListening();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_shakeCount / _requiredShakes).clamp(0.0, 1.0);
    return Column(
      children: [
        const Icon(Icons.vibration_rounded, size: 40, color: AppColors.white),
        const SizedBox(height: 10),
        Text(
          'Shake your phone! ($_shakeCount/$_requiredShakes)',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.white),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SOLVE DISMISS
// ═══════════════════════════════════════════════════════════════════════════════

class _SolveDismiss extends StatefulWidget {
  const _SolveDismiss({required this.onDismissed});
  final VoidCallback onDismissed;
  @override
  State<_SolveDismiss> createState() => _SolveDismissState();
}

class _SolveDismissState extends State<_SolveDismiss>
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
    return AnimatedBuilder(
      animation: _shakeOffset,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeOffset.value, 0),
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NumBox(value: _numA.toString()),
          const SizedBox(width: 10),
          Text(_operator,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white)),
          const SizedBox(width: 10),
          _NumBox(value: _numB.toString()),
          const SizedBox(width: 10),
          const Text('=',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white)),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            height: 52,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _wrong ? AppColors.error : AppColors.white,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _controller,
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
                    color: AppColors.white),
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
    );
  }
}

class _NumBox extends StatelessWidget {
  const _NumBox({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(value,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.white)),
      ),
    );
  }
}
