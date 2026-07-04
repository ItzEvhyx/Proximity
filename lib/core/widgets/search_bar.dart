import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
  });

  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onMicTap;
  final ValueChanged<String>? onSearchTap;

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
  void dispose() {
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Image.asset(
            'public/assets/icons/alarm_clock_icon.png',
            width: 30,
            height: 30,
            fit: BoxFit.contain,
            color: AppColors.primary,
            colorBlendMode: BlendMode.srcIn,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
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
          _ActionIcon(icon: Icons.mic_rounded, onTap: widget.onMicTap),
          const SizedBox(width: 10),
          _ActionIcon(
            icon: Icons.search_rounded,
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
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(icon, color: AppColors.primary, size: 30),
    );
  }
}
