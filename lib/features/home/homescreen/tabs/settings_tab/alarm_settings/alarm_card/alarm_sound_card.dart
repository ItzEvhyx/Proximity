import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../../../../core/shared_prefs/shared_prefs.dart';
import '../../../../../../../core/supabase/supabase_client.dart';
import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/widgets/asset_icon.dart';

/// Data model for an alarm sound option.
class _AlarmOption {
  const _AlarmOption({required this.key, required this.label, required this.asset});

  /// Unique key stored in prefs/DB (e.g. 'default_alarm').
  final String key;

  /// Display name shown in the picker.
  final String label;

  /// Asset path relative to the project root.
  final String asset;
}

/// Data model for a category of alarm sounds.
class _AlarmCategory {
  const _AlarmCategory({
    required this.title,
    required this.icon,
    required this.options,
    this.expandable = true,
  });

  final String title;
  final String icon;
  final List<_AlarmOption> options;
  final bool expandable;
}

// ── Alarm sound definitions ──────────────────────────────────────────────────

const _standardOption = _AlarmOption(
  key: 'default_alarm',
  label: 'Default Alarm',
  asset: 'public/assets/audio/default_alarm.mp3',
);

const _calmingOptions = [
  _AlarmOption(
    key: 'birds_chirping',
    label: 'Birds Chirping',
    asset: 'public/assets/audio/calming alarms/birds_chirping_alarm.mp3',
  ),
  _AlarmOption(
    key: 'life_core',
    label: 'Life Core',
    asset: 'public/assets/audio/calming alarms/life_core_alarm.mp3',
  ),
  _AlarmOption(
    key: 'piano',
    label: 'Piano',
    asset: 'public/assets/audio/calming alarms/piano_alarm.mp3',
  ),
];

const _intenseOptions = [
  _AlarmOption(
    key: 'air_raid',
    label: 'Air Raid',
    asset: 'public/assets/audio/intense alarms/air_raid_salarm.mp3',
  ),
  _AlarmOption(
    key: 'alarm_clock',
    label: 'Alarm Clock',
    asset: 'public/assets/audio/intense alarms/alarm_clock_tone.mp3',
  ),
  _AlarmOption(
    key: 'loud_alarm',
    label: 'Loud Alarm',
    asset: 'public/assets/audio/intense alarms/loud_alarm.mp3',
  ),
];

final _categories = [
  const _AlarmCategory(
    title: 'Standard',
    icon: 'public/assets/icons/alarm_clock_icon.png',
    options: [_standardOption],
    expandable: false,
  ),
  const _AlarmCategory(
    title: 'Calming',
    icon: 'public/assets/icons/calming_icon.png',
    options: _calmingOptions,
  ),
  const _AlarmCategory(
    title: 'Intense',
    icon: 'public/assets/icons/comic_fx_icon.png',
    options: _intenseOptions,
  ),
  const _AlarmCategory(
    title: 'Custom Alarms',
    icon: '',
    options: [],
  ),
];

/// Shows the alarm sound picker as a bottom sheet modal.
/// Returns the selected alarm key, or null if dismissed.
Future<String?> showAlarmSoundPicker(BuildContext context) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AlarmSoundPickerSheet(),
  );
}

class _AlarmSoundPickerSheet extends StatefulWidget {
  const _AlarmSoundPickerSheet();

  @override
  State<_AlarmSoundPickerSheet> createState() => _AlarmSoundPickerSheetState();
}

class _AlarmSoundPickerSheetState extends State<_AlarmSoundPickerSheet> {
  late String _selected;
  final AudioPlayer _player = AudioPlayer();
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _selected = AppPrefs.alarmSound;
    // Auto-expand the category containing the current selection.
    for (var i = 0; i < _categories.length; i++) {
      if (_categories[i].options.any((o) => o.key == _selected)) {
        _expandedIndex = _categories[i].expandable ? i : null;
        break;
      }
    }
    // Loop playback with a 1-second pause between repeats.
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && _player.processingState == ProcessingState.completed) {
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
    super.dispose();
  }

  Future<void> _onSelect(_AlarmOption option) async {
    // Deselect: if tapping the already-selected sound, fall back to default.
    final effectiveKey =
        (_selected == option.key) ? _standardOption.key : option.key;
    final effectiveOption = (_selected == option.key) ? _standardOption : option;

    setState(() => _selected = effectiveKey);

    // Play preview in loop (stream listener handles repeat).
    try {
      await _player.stop();
      await _player.setAsset(effectiveOption.asset);
      _player.play();
    } catch (_) {}

    // Save locally + to DB.
    await AppPrefs.setAlarmSound(effectiveKey);
    _saveToDatabase(effectiveKey);
  }

  Future<void> _saveToDatabase(String key) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await supabase
          .from('profiles')
          .update({'alarm_sound': key}).eq('id', userId);
    } catch (_) {}
  }

  void _toggleCategory(int index) {
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null;
        // Stop playback when collapsing the category.
        _player.stop();
      } else {
        _expandedIndex = index;
        // Stop playback when switching to a different category.
        _player.stop();
      }
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
          const SizedBox(height: 16),
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Alarm Sound',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Categories list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 24),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final cat = _categories[index];
                return _CategoryCard(
                  category: cat,
                  expanded: _expandedIndex == index,
                  selected: _selected,
                  onToggle: cat.expandable ? () => _toggleCategory(index) : null,
                  onSelect: _onSelect,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.expanded,
    required this.selected,
    required this.onToggle,
    required this.onSelect,
  });

  final _AlarmCategory category;
  final bool expanded;
  final String selected;
  final VoidCallback? onToggle;
  final ValueChanged<_AlarmOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final isCustom = category.title == 'Custom Alarms';
    final isStandard = !category.expandable && category.options.isNotEmpty;
    final isSelected = isStandard && category.options.first.key == selected;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isSelected || expanded)
              ? AppColors.primary
              : AppColors.border,
          width: (isSelected || expanded) ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          InkWell(
            onTap: isStandard
                ? () => onSelect(category.options.first)
                : isCustom
                    ? null
                    : onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon
                  if (isCustom)
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    AssetIcon(category.icon, size: 28, color: AppColors.primary),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Text(
                      category.title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  // Selection indicator for standard / expand chevron
                  if (isStandard)
                    _RadioDot(selected: isSelected)
                  else if (!isCustom)
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textGrey,
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Expanded options
          if (category.expandable && expanded)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  for (final option in category.options)
                    _OptionTile(
                      option: option,
                      isSelected: option.key == selected,
                      onTap: () => onSelect(option),
                    ),
                ],
              ),
            ),
          // Custom alarms placeholder
          if (isCustom) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.upload_rounded,
                    size: 18,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Upload Alarm',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _AlarmOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.primary : AppColors.textDark,
                ),
              ),
            ),
            _RadioDot(selected: isSelected),
          ],
        ),
      ),
    );
  }
}

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
