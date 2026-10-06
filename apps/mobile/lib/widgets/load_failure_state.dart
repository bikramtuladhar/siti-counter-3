import 'package:flutter/material.dart';

import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

/// Shown when something failed to load and there is nothing to display.
///
/// Exists because the failure path was open-coded and inconsistent: one screen reported an
/// error while another left its loading spinner on screen forever, which looks like the app is
/// still working. A failure has to be visible and retryable to be recoverable.
class LoadFailureState extends StatelessWidget {
  final String title;
  final String? detail;
  final VoidCallback? onRetry;
  final String retryLabel;

  const LoadFailureState({
    super.key,
    required this.title,
    this.detail,
    this.onRetry,
    String? retryLabel,
  }) : retryLabel = retryLabel ?? 'Try again';

  /// English and Nepali copy for a failed load, with an optional detail line.
  factory LoadFailureState.bilingual({
    required bool preferNepali,
    String? detailEn,
    String? detailNe,
    VoidCallback? onRetry,
  }) =>
      LoadFailureState(
        title: preferNepali ? 'लोड गर्न सकिएन' : 'Could not load',
        detail: preferNepali ? detailNe : detailEn,
        onRetry: onRetry,
        retryLabel: preferNepali ? 'पुनः प्रयास' : 'Try again',
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: SitiColors.alert,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: NepaliTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: SitiColors.dark,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: NepaliTypography.bodySmall.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('load_failure_retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}