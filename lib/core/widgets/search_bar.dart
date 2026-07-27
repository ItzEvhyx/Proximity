import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'asset_icon.dart';

/// Floating location search bar shared by the Maps and Routes tabs.
///
/// A white pill with the brand alarm-clock icon, an editable "Search
/// Location..." field, and microphone + search icons (from the Material icon
/// library) on the right. Tapping anywhere on the pill focuses the field so
/// the user can type immediately.
///
/// Pass a [controller] to read/observe the text, or use [onChanged] /
/// [onSubmitted] callbacks. [onMicTap] and [onSearchTap] handle the trailing
/// icons; [onSearchTap] falls back to submitting the current text.
class LocationSearchBar extends StatefulWidget {
  const LocationSearchBar({
    super.key,
    this.hintText = 'Search Location...',
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onMicTap,
    this.onSearchTap,
    this.micActive = false,
    this.disabled = false,
    this.showMic = true,
  });

  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onMicTap;
  final ValueChanged<String>? onSearchTap;

  /// When true the mic is actively listening; shown in an accent "recording"
  /// state.
  final bool micActive;

  /// When true, the search bar is greyed out and non-interactive.
  final bool disabled;

  /// Whether to show the mic icon. Set to false for contexts where
  /// speech-to-text is not available (e.g. Finder tab).
  final bool showMic;

  @override
  State<LocationSearchBar> createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends State<LocationSearchBar> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStateChanged);
    _focusNode.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(LocationSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onStateChanged);
      _controller.addListener(_onStateChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onStateChanged);
      _focusNode.addListener(_onStateChanged);
    }
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  /// The clear (X) button shows when the field is focused and holds text, so
  /// the user can wipe the whole entry in one tap.
  bool get _showClear => _focusNode.hasFocus && _controller.text.isNotEmpty;

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    // Keep the field focused so the user can immediately type again.
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    _focusNode.removeListener(_onStateChanged);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled;
    final iconColor = isDisabled
        ? AppColors.hintGrey.withValues(alpha: 0.5)
        : AppColors.primary;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: IgnorePointer(
        ignoring: isDisabled,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              AssetIcon(
                'public/assets/icons/alarm_clock_icon.png',
                size: 30,
                color: iconColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  onTapOutside: (_) {},
                  textInputAction: TextInputAction.search,
                  cursorColor: AppColors.primary,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.hintGrey,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_showClear) ...[
                _ActionIcon(icon: Icons.close_rounded, onTap: _clear),
                const SizedBox(width: 10),
              ],
              if (widget.showMic) ...[
                _ActionIcon(
                  icon: widget.micActive ? Icons.mic : Icons.mic_rounded,
                  onTap: widget.onMicTap,
                  color: widget.micActive ? AppColors.error : iconColor,
                ),
                const SizedBox(width: 10),
              ],
              _ActionIcon(
                icon: Icons.search_rounded,
                color: iconColor,
                onTap: () {
                  final text = _controller.text;
                  if (widget.onSearchTap != null) {
                    widget.onSearchTap!(text);
                  } else {
                    widget.onSubmitted?.call(text);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, this.onTap, this.color});

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(icon, color: color ?? AppColors.primary, size: 30),
    );
  }
}
