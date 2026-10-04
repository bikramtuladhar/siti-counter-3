library;

import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../audio/kitchen_voice_controller.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

/// Hands-free kitchen voice control bar & overlay.
///
/// Designed for low-literacy users and wet-hand cooking environments (Section 13.3 & 16.1):
/// - Large, high-contrast mic trigger with pulsing animation.
/// - Prominent low-literacy icons depicting recognized intents.
/// - Live feedback badge displaying command confirmation in Nepali & English.
/// - Privacy guarantee banner confirming 100% on-device audio processing.
class KitchenVoiceBar extends StatefulWidget {
  final KitchenVoiceController controller;
  final String currentLanguage;
  final VoidCallback? onVoiceActionTriggered;

  const KitchenVoiceBar({
    super.key,
    required this.controller,
    this.currentLanguage = 'ne',
    this.onVoiceActionTriggered,
  });

  @override
  State<KitchenVoiceBar> createState() => _KitchenVoiceBarState();
}

class _KitchenVoiceBarState extends State<KitchenVoiceBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TextEditingController _textFallbackController = TextEditingController();

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    widget.controller.stateNotifier.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (!mounted) return;
    if (widget.controller.state == VoiceControllerState.listening) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    widget.controller.stateNotifier.removeListener(_onStateChanged);
    _pulseController.dispose();
    _textFallbackController.dispose();
    super.dispose();
  }

  void _openVoiceDialog() {
    widget.controller.startListening();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildVoiceBottomSheet(ctx),
    ).whenComplete(() {
      widget.controller.stopListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VoiceControllerState>(
      valueListenable: widget.controller.stateNotifier,
      builder: (context, state, _) {
        return ValueListenableBuilder<KitchenVoiceCommand?>(
          valueListenable: widget.controller.lastCommandNotifier,
          builder: (context, lastCmd, _) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: state == VoiceControllerState.listening
                      ? SitiColors.terracotta
                      : Colors.grey.shade200,
                  width: state == VoiceControllerState.listening ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Mic Button with Pulse Animation when listening
                  GestureDetector(
                    key: const Key('kitchen_voice_mic_button'),
                    onTap: _openVoiceDialog,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = state == VoiceControllerState.listening
                            ? 1.0 + (_pulseController.value * 0.15)
                            : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: state == VoiceControllerState.listening
                                  ? SitiColors.terracotta
                                  : SitiColors.terracotta.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              state == VoiceControllerState.listening
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              color: state == VoiceControllerState.listening
                                  ? Colors.white
                                  : SitiColors.terracotta,
                              size: 26,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Low-Literacy Status & Feedback
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (lastCmd != null &&
                                lastCmd.intent != KitchenVoiceIntent.unknown) ...[
                              Icon(
                                _getIntentIcon(lastCmd.intent),
                                size: 16,
                                color: SitiColors.terracotta,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _getStatusTitle(state, lastCmd),
                              style: NepaliTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: state == VoiceControllerState.error
                                    ? Colors.red.shade700
                                    : SitiColors.dark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getFeedbackSubtitle(state, lastCmd),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NepaliTypography.bodySmall.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Voice Action Button
                  IconButton(
                    key: const Key('kitchen_voice_expand_button'),
                    icon: const Icon(Icons.record_voice_over_rounded, color: SitiColors.dark),
                    tooltip: _isNepali ? 'आवाज कमान्ड' : 'Voice Commands',
                    onPressed: _openVoiceDialog,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVoiceBottomSheet(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with privacy assurance
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SitiColors.terracotta.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_rounded, color: SitiColors.terracotta, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNepali ? 'हात नछोई आवाज नियन्त्रण' : 'Hands-Free Kitchen Voice',
                        style: NepaliTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: SitiColors.dark,
                        ),
                      ),
                      Text(
                        _isNepali
                            ? '१००% डिभाइसमा प्रशोधन • आवाज रेकर्ड गरिँदैन'
                            : '100% on-device • Audio is never uploaded',
                        style: NepaliTypography.labelSmall.copyWith(
                          color: Colors.teal.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Spoken Transcript / Live Feedback Display
            ValueListenableBuilder<String>(
              valueListenable: widget.controller.recognizedTextNotifier,
              builder: (context, transcript, _) {
                final hasText = transcript.trim().isNotEmpty;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SitiColors.warmWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasText ? Icons.check_circle_outline : Icons.graphic_eq_rounded,
                        color: hasText ? Colors.green.shade700 : SitiColors.terracotta,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hasText
                              ? transcript
                              : (_isNepali
                                  ? 'कमान्ड भन्नुहोस् (उदा. "अर्को चरण", "कति सिट्ठी बाँकी?")'
                                  : 'Say a command (e.g. "Next step", "How many siti left?")'),
                          style: NepaliTypography.bodyMedium.copyWith(
                            fontStyle: hasText ? FontStyle.normal : FontStyle.italic,
                            color: hasText ? SitiColors.dark : Colors.grey.shade500,
                            fontWeight: hasText ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Low-Literacy Quick Command Chips (Tap or Speak)
            Text(
              _isNepali ? 'प्रचलित भान्सा कमान्डहरू:' : 'Common Kitchen Commands:',
              style: NepaliTypography.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCommandChip(
                  icon: Icons.soup_kitchen_rounded,
                  label: _isNepali ? 'कति सिट्ठी बाँकी?' : 'How many siti left?',
                  phrase: _isNepali ? 'कति सिट्ठी बाँकी छ?' : 'How many siti left?',
                ),
                _buildCommandChip(
                  icon: Icons.skip_next_rounded,
                  label: _isNepali ? 'अर्को चरण' : 'Next step',
                  phrase: _isNepali ? 'अर्को चरण' : 'Next step',
                ),
                _buildCommandChip(
                  icon: Icons.timer_rounded,
                  label: _isNepali ? '५ मिनेटको टाइमर' : 'Set 5 min timer',
                  phrase: _isNepali ? '५ मिनेटको टाइमर राख' : 'Set timer for 5 minutes',
                ),
                _buildCommandChip(
                  icon: Icons.shopping_basket_rounded,
                  label: _isNepali ? 'नून सूचीमा थप' : 'Add salt to list',
                  phrase: _isNepali ? 'नून बजार सूचीमा थप' : 'Add salt to grocery list',
                ),
                _buildCommandChip(
                  icon: Icons.pause_circle_outline_rounded,
                  label: _isNepali ? 'टाइमर रोक' : 'Pause timer',
                  phrase: _isNepali ? 'टाइमर रोक' : 'Pause timer',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Manual Text Input Fallback (for testing / silent kitchens)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('kitchen_voice_text_fallback_field'),
                    controller: _textFallbackController,
                    decoration: InputDecoration(
                      hintText: _isNepali ? 'वा कमान्ड टाइप गर्नुहोस्...' : 'Or type a command...',
                      hintStyle: NepaliTypography.bodySmall.copyWith(color: Colors.grey.shade400),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        widget.controller.processUtterance(val);
                        _textFallbackController.clear();
                        Navigator.of(ctx).pop();
                        widget.onVoiceActionTriggered?.call();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('kitchen_voice_send_button'),
                  icon: const Icon(Icons.send_rounded, color: SitiColors.terracotta),
                  onPressed: () {
                    final text = _textFallbackController.text;
                    if (text.trim().isNotEmpty) {
                      widget.controller.processUtterance(text);
                      _textFallbackController.clear();
                      Navigator.of(ctx).pop();
                      widget.onVoiceActionTriggered?.call();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandChip({
    required IconData icon,
    required String label,
    required String phrase,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: SitiColors.terracotta),
      label: Text(label, style: NepaliTypography.bodySmall.copyWith(fontSize: 12)),
      backgroundColor: SitiColors.warmWhite,
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: () {
        widget.controller.processUtterance(phrase);
        Navigator.of(context).pop();
        widget.onVoiceActionTriggered?.call();
      },
    );
  }

  String _getStatusTitle(VoiceControllerState state, KitchenVoiceCommand? cmd) {
    if (state == VoiceControllerState.listening) {
      return _isNepali ? 'सुन्दैछ...' : 'Listening...';
    }
    if (state == VoiceControllerState.processing) {
      return _isNepali ? 'बुझ्दैछ...' : 'Processing...';
    }
    if (cmd != null && cmd.intent != KitchenVoiceIntent.unknown) {
      switch (cmd.intent) {
        case KitchenVoiceIntent.queryWhistles:
          return _isNepali ? 'सिट्ठी जाँच' : 'Whistle Check';
        case KitchenVoiceIntent.nextStep:
          return _isNepali ? 'अर्को चरण' : 'Next Step';
        case KitchenVoiceIntent.previousStep:
          return _isNepali ? 'अघिल्लो चरण' : 'Previous Step';
        case KitchenVoiceIntent.repeatStep:
          return _isNepali ? 'चरण दोहोर्याइयो' : 'Step Repeated';
        case KitchenVoiceIntent.setTimer:
          return _isNepali ? 'टाइमर सेट' : 'Timer Set';
        case KitchenVoiceIntent.pauseTimer:
          return _isNepali ? 'टाइमर रोकियो' : 'Timer Paused';
        case KitchenVoiceIntent.resumeTimer:
          return _isNepali ? 'टाइमर सुचारु' : 'Timer Resumed';
        case KitchenVoiceIntent.addGrocery:
          return _isNepali ? 'बजार सूची' : 'Grocery Added';
        case KitchenVoiceIntent.queryBoilingPoint:
          return _isNepali ? 'उम्लने तापक्रम' : 'Boiling Point';
        case KitchenVoiceIntent.unknown:
          break;
      }
    }
    return _isNepali ? 'हात नछोई आवाज कमान्ड' : 'Hands-Free Kitchen Voice';
  }

  String _getFeedbackSubtitle(VoiceControllerState state, KitchenVoiceCommand? cmd) {
    if (state == VoiceControllerState.listening) {
      return _isNepali
          ? '"अर्को चरण", "कति सिट्ठी?", "५ मिनेट टाइमर"'
          : 'Say "next step", "how many siti", "set timer"';
    }
    if (cmd != null) {
      return _isNepali ? cmd.feedbackNe : cmd.feedbackEn;
    }
    return _isNepali
        ? 'भिजेको हातले खाना पकाउँदा आवाजबाट नियन्त्रण गर्नुहोस्'
        : 'Control cooking with voice while hands are wet';
  }

  IconData _getIntentIcon(KitchenVoiceIntent intent) {
    switch (intent) {
      case KitchenVoiceIntent.queryWhistles:
        return Icons.soup_kitchen_rounded;
      case KitchenVoiceIntent.nextStep:
        return Icons.skip_next_rounded;
      case KitchenVoiceIntent.previousStep:
        return Icons.skip_previous_rounded;
      case KitchenVoiceIntent.repeatStep:
        return Icons.replay_rounded;
      case KitchenVoiceIntent.setTimer:
        return Icons.timer_rounded;
      case KitchenVoiceIntent.pauseTimer:
        return Icons.pause_circle_outline_rounded;
      case KitchenVoiceIntent.resumeTimer:
        return Icons.play_circle_outline_rounded;
      case KitchenVoiceIntent.addGrocery:
        return Icons.shopping_basket_rounded;
      case KitchenVoiceIntent.queryBoilingPoint:
        return Icons.thermostat_rounded;
      case KitchenVoiceIntent.unknown:
        return Icons.help_outline_rounded;
    }
  }
}
