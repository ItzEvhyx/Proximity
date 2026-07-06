import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_colors.dart';

/// "IMPORTANT NOTES" card — green rounded card with a warning icon and
/// a list of notes. Shared across all non-train transit types; the content
/// is driven by the [notes] list passed in from the data model.
class ImportantNotesCard extends StatelessWidget {
  const ImportantNotesCard({super.key, required this.notes});

  final List<String> notes;

  static final Color _gradientEnd =
      Color.lerp(AppColors.primary, Colors.black, 0.12)!;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary, _gradientEnd],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: warning icon + title
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '!',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'IMPORTANT NOTES',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Notes body
            for (var i = 0; i < notes.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Text(
                notes[i],
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
