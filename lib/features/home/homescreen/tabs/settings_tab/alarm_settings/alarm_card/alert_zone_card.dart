import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../../core/shared_prefs/shared_prefs.dart';
import '../../../../../../../core/supabase/supabase_client.dart';
import '../../../../../../../core/theme/app_colors.dart';

/// Shows the alert zone distance picker as a bottom sheet modal.
/// Returns true if the user saved, null if dismissed.
Future<bool?> showAlertZonePicker(BuildContext context) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AlertZonePickerSheet(),
  );
}

class _AlertZonePickerSheet extends StatefulWidget {
  const _AlertZonePickerSheet();

  @override
  State<_AlertZonePickerSheet> createState() => _AlertZonePickerSheetState();
}

class _AlertZonePickerSheetState extends State<_AlertZonePickerSheet> {
  late bool _isMeters; // true = meters, false = kilometers
  late List<TextEditingController> _controllers;
  int _phaseCount = 1;

  @override
  void initState() {
    super.initState();
    _isMeters = AppPrefs.alertZoneUnit == 'meters';
    final distances = AppPrefs.alertZoneDistances;
    _phaseCount = distances.length.clamp(1, 3);
    _controllers = List.generate(3, (i) {
      final value = i < distances.length ? distances[i] : 0;
      final displayValue = _isMeters ? value : (value / 1000);
      final text =
          i < distances.length ? _formatValue(displayValue) : '';
      return TextEditingController(text: text);
    });
  }

  String _formatValue(num value) {
    if (value == value.toInt()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Parse the text field value to meters (always store in meters).
  int _parseToMeters(String text) {
    final val = double.tryParse(text) ?? 0;
    if (_isMeters) return val.round();
    return (val * 1000).round();
  }

  Future<void> _save() async {
    final distances = <int>[];
    for (var i = 0; i < _phaseCount; i++) {
      final meters = _parseToMeters(_controllers[i].text);
      if (meters > 0) distances.add(meters);
    }

    // Validate: each phase must be smaller than the previous.
    for (var i = 1; i < distances.length; i++) {
      if (distances[i] >= distances[i - 1]) {
        _showError('Phase ${i + 1} must be a smaller distance than Phase $i.');
        return;
      }
    }

    if (distances.isEmpty) {
      _showError('Please enter at least one distance.');
      return;
    }

    await AppPrefs.setAlertZoneDistances(distances);
    await AppPrefs.setAlertZoneUnit(_isMeters ? 'meters' : 'km');
    _saveToDatabase(distances);

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _saveToDatabase(List<int> distances) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await supabase.from('profiles').update({
        'alert_zone_distances': distances,
      }).eq('id', userId);
    } catch (_) {}
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addPhase() {
    if (_phaseCount >= 3) return;
    setState(() => _phaseCount++);
  }

  void _removePhase(int index) {
    if (_phaseCount <= 1) return;
    setState(() {
      _controllers[index].clear();
      // Shift controllers down.
      for (var i = index; i < _phaseCount - 1; i++) {
        _controllers[i].text = _controllers[i + 1].text;
      }
      _controllers[_phaseCount - 1].clear();
      _phaseCount--;
    });
  }

  void _toggleUnit(bool meters) {
    if (_isMeters == meters) return;
    setState(() {
      // Convert existing values.
      for (var i = 0; i < _phaseCount; i++) {
        final currentMeters = _parseToMeters(_controllers[i].text);
        if (currentMeters > 0) {
          _isMeters = meters;
          final displayValue =
              meters ? currentMeters.toDouble() : currentMeters / 1000;
          _controllers[i].text = _formatValue(displayValue);
        }
      }
      _isMeters = meters;
    });
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
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + bottomPadding + 24),
        child: SingleChildScrollView(
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
              'Alert Zone',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 18),
            // Meters / Kilometers toggle
            _UnitToggle(
              isMeters: _isMeters,
              onChanged: _toggleUnit,
            ),
            const SizedBox(height: 20),
            // Phase inputs
            for (var i = 0; i < _phaseCount; i++) ...[
              _PhaseInput(
                phaseIndex: i,
                controller: _controllers[i],
                unitLabel: _isMeters ? 'm' : 'Km',
                canRemove: _phaseCount > 1,
                onRemove: () => _removePhase(i),
              ),
              const SizedBox(height: 14),
            ],
            // Add phase button
            if (_phaseCount < 3) ...[
              GestureDetector(
                onTap: _addPhase,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Add Phase ${_phaseCount + 1}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
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
      ),
    );
  }
}

/// Meters / Kilometers segmented toggle.
class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.isMeters, required this.onChanged});

  final bool isMeters;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleOption('Meters', isMeters, () => onChanged(true))),
          Expanded(
              child:
                  _toggleOption('Kilometers', !isMeters, () => onChanged(false))),
        ],
      ),
    );
  }

  Widget _toggleOption(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single phase distance input row.
class _PhaseInput extends StatelessWidget {
  const _PhaseInput({
    required this.phaseIndex,
    required this.controller,
    required this.unitLabel,
    required this.canRemove,
    required this.onRemove,
  });

  final int phaseIndex;
  final TextEditingController controller;
  final String unitLabel;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Phase ${phaseIndex + 1}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textGrey,
              ),
            ),
            if (canRemove) ...[
              const Spacer(),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textGrey.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Text field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Distance',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.textGrey.withValues(alpha: 0.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Unit badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                unitLabel,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
