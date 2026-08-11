import 'package:flutter/material.dart';

import '../../../../../../../core/global_services/vibration_service.dart';
import '../../../../../../../core/shared_prefs/shared_prefs.dart';
import '../../../../../../../core/supabase/supabase_client.dart';
import '../../../../../../../core/theme/app_colors.dart';

/// Shows the vibration intensity picker as a bottom sheet modal.
/// Returns true if the user saved, null if dismissed.
Future<bool?> showVibrationPicker(BuildContext context) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VibrationPickerSheet(),
  );
}

/// Data model for a vibration option.
class _VibrationOption {
  const _VibrationOption({
    required this.key,
    required this.label,
    required this.sub,
    required this.bars,
  });

  final String key;
  final String label;
  final String sub;

  /// Number of bars to show in the icon (0–4).
  final int bars;
}

const _vibrationOptions = [
  _VibrationOption(
    key: 'off',
    label: 'Off',
    sub: 'Sound and notification only',
    bars: 0,
  ),
  _VibrationOption(
    key: 'light',
    label: 'Light',
    sub: 'A subtle pulse',
    bars: 1,
  ),
  _VibrationOption(
    key: 'medium',
    label: 'Medium',
    sub: 'Noticeable, not jarring',
    bars: 2,
  ),
  _VibrationOption(
    key: 'strong',
    label: 'Strong',
    sub: 'Maximum intensity',
    bars: 3,
  ),
];

class _VibrationPickerSheet extends StatefulWidget {
  const _VibrationPickerSheet();

  @override
  State<_VibrationPickerSheet> createState() => _VibrationPickerSheetState();
}

class _VibrationPickerSheetState extends State<_VibrationPickerSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = AppPrefs.vibrationIntensity;
  }

  void _onSelect(String key) {
    setState(() => _selected = key);
    // Immediately preview the vibration at the selected intensity.
    if (key == 'off') {
      VibrationService.instance.stop();
    } else {
      VibrationService.instance.start(intensityOverride: key);
    }
  }

  Future<void> _save() async {
    VibrationService.instance.stop();
    await AppPrefs.setVibrationIntensity(_selected);
    _saveToDatabase(_selected);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _saveToDatabase(String key) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await supabase
          .from('profiles')
          .update({'vibration_intensity': key}).eq('id', userId);
    } catch (_) {}
  }

  @override
  void dispose() {
    // Stop vibration preview if user dismisses without saving.
    VibrationService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const Text(
              'Vibration Intensity',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 20),
            // Options
            for (final option in _vibrationOptions) ...[
              _VibrationRow(
                option: option,
                isSelected: option.key == _selected,
                onTap: () => _onSelect(option.key),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            // Save button
            GestureDetector(
              onTap: _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
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

/// A selectable vibration option row.
class _VibrationRow extends StatelessWidget {
  const _VibrationRow({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _VibrationOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Vibration bars icon
            _VibrationBars(bars: option.bars, active: isSelected),
            const SizedBox(width: 14),
            // Label + sub
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.sub,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            // Radio dot
            _RadioDot(selected: isSelected),
          ],
        ),
      ),
    );
  }
}

/// Visual indicator showing vibration strength as bars.
class _VibrationBars extends StatelessWidget {
  const _VibrationBars({required this.bars, required this.active});

  final int bars;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textGrey;

    if (bars == 0) {
      // "Off" — show dots
      return SizedBox(
        width: 24,
        height: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            4,
            (_) => Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 24,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final filled = i < bars;
          final heights = [8.0, 14.0, 20.0];
          return Container(
            width: 5,
            height: heights[i],
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: filled ? color : color.withValues(alpha: 0.2),
            ),
          );
        }),
      ),
    );
  }
}

/// Radio dot matching the alarm sound picker style.
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
            )
          : null,
    );
  }
}
