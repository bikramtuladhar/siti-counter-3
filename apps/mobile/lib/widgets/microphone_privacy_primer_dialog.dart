import 'package:flutter/material.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

/// Result of user decision in the Microphone Privacy Primer dialog.
enum MicrophonePrimerDecision {
  allowAcoustic,
  manualOnly,
}

/// A privacy-first modal dialog / bottom sheet explaining why microphone access
/// is needed, emphasizing 100% on-device processing and zero cloud recording.
class MicrophonePrivacyPrimerDialog extends StatelessWidget {
  final String language;

  const MicrophonePrivacyPrimerDialog({
    super.key,
    this.language = 'ne',
  });

  bool get _isNepali => language == 'ne';

  /// Shows the privacy primer bottom sheet modal.
  static Future<MicrophonePrimerDecision?> show(
    BuildContext context, {
    String language = 'ne',
  }) {
    return showModalBottomSheet<MicrophonePrimerDecision>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MicrophonePrivacyPrimerDialog(language: language),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Shield Icon & Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SitiColors.terracotta.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: SitiColors.terracotta,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNepali
                            ? 'गोपनीयता र माइक अनुमति'
                            : 'Microphone & Privacy',
                        style: NepaliTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: SitiColors.dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isNepali
                            ? '१००% अन-डिभाइस सिट्ठी पहिचान'
                            : '100% On-Device Whistle Detection',
                        style: NepaliTypography.labelSmall.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Highlight Box: Audio Never Leaves Phone
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: Colors.green.shade800,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isNepali
                          ? 'तपाईंको आवाज कहिल्यै फोन बाहिर जाँदैन — सिट्ठीको आवाज प्रत्यक्ष फोनमै प्रशोधन हुन्छ र तुरुन्तै हटाइन्छ।'
                          : 'Your audio never leaves your phone — whistle acoustic patterns are processed 100% on-device and instantly discarded.',
                      style: NepaliTypography.bodySmall.copyWith(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Feature points
            _buildFeatureRow(
              icon: Icons.mic_external_off_rounded,
              title: _isNepali ? 'कुनै अडियो रेकर्ड हुँदैन' : 'No Recording Stored',
              description: _isNepali
                  ? 'कुनै पनि आवाज वा कुराकानी सेभ वा सर्भरमा पठाइँदैन।'
                  : 'No audio, voices, or conversations are recorded or uploaded to any server.',
            ),
            const SizedBox(height: 10),
            _buildFeatureRow(
              icon: Icons.battery_charging_full_rounded,
              title: _isNepali ? 'न्यूनतम ब्याट्री खपत' : 'Low Battery Usage',
              description: _isNepali
                  ? 'पृष्ठभूमिमा चल्दा पनि हलुका FFT अडियो एल्गोरिदम प्रयोग हुन्छ।'
                  : 'Uses lightweight local FFT frequency filtering optimized for battery life.',
            ),
            const SizedBox(height: 10),
            _buildFeatureRow(
              icon: Icons.touch_app_rounded,
              title: _isNepali ? 'सधैं म्यानुअल विकल्प उपलब्ध' : 'Manual Tap Always Available',
              description: _isNepali
                  ? 'यदि माइक प्रयोग गर्न चाहनुहुन्न भने हातले +१ बटन थिचेर गन्न सक्नुहुन्छ।'
                  : 'You can always opt to count manually using the large +1 tactile button.',
            ),
            const SizedBox(height: 24),

            // Action Buttons
            ElevatedButton.icon(
              key: const Key('primer_allow_button'),
              onPressed: () => Navigator.of(context).pop(MicrophonePrimerDecision.allowAcoustic),
              icon: const Icon(Icons.mic_rounded, size: 20),
              label: Text(
                _isNepali
                    ? 'अनुमति दिनुहोस् र सुरु गर्नुहोस्'
                    : 'Allow & Start Listening',
                style: NepaliTypography.titleSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SitiColors.terracotta,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
            const SizedBox(height: 10),

            OutlinedButton.icon(
              key: const Key('primer_manual_button'),
              onPressed: () => Navigator.of(context).pop(MicrophonePrimerDecision.manualOnly),
              icon: const Icon(Icons.touch_app_rounded, size: 18),
              label: Text(
                _isNepali ? 'म्यानुअल मोड मात्र (कुनै माइक चाहिँदैन)' : 'Manual Tap Only (No Mic)',
                style: NepaliTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: SitiColors.terracotta),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: NepaliTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SitiColors.dark,
                ),
              ),
              Text(
                description,
                style: NepaliTypography.bodySmall.copyWith(
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
