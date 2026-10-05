import 'package:flutter/material.dart';

import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

/// Compact language switcher (नेपाली / English).
///
/// Shown in onboarding so the first thing a new user reads is in a language they can read:
/// the welcome tour is otherwise Nepali-only, so an English or diaspora speaker would have to
/// guess their way through it before reaching the wizard's language question.
class LanguageToggle extends StatelessWidget {
  /// Current language code: `ne` or `en`.
  final String language;

  final ValueChanged<String> onChanged;

  /// Compact drops the labels to fit a tight app bar; used in the welcome tour header.
  final bool compact;

  const LanguageToggle({
    super.key,
    required this.language,
    required this.onChanged,
    this.compact = false,
  });

  static const String nepali = 'ne';
  static const String english = 'en';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: SitiColors.terracotta.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SitiColors.terracotta.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            context,
            code: nepali,
            label: 'ने',
            semanticLabel: 'नेपाली',
          ),
          _segment(
            context,
            code: english,
            label: 'EN',
            semanticLabel: 'English',
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String code,
    required String label,
    required String semanticLabel,
  }) {
    final isSelected = language == code;
    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      child: InkWell(
        key: Key('language_toggle_$code'),
        onTap: () {
          if (!isSelected) onChanged(code);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: isSelected ? SitiColors.terracotta : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: NepaliTypography.labelLarge.copyWith(
              color: isSelected ? Colors.white : SitiColors.terracotta,
              fontSize: compact ? 12 : 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}