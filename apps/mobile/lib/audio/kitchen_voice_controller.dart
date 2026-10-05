library;

import 'package:flutter/foundation.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

/// State of the hands-free voice controller.
enum VoiceControllerState {
  idle,
  listening,
  processing,
  recognized,
  error,
}

/// Hands-free voice controller for kitchen cooktops & low-literacy users (Section 13.3, 16.1).
///
/// Features:
/// - Deterministic, offline-first command parsing via `KitchenVoiceEngine`.
/// - 100% on-device speech processing with zero audio transmission (Privacy guarantee).
/// - Multilingual support: English, Nepali, Hindi.
/// - Clean callbacks for active cooking steps, timers, whistle queries, and grocery list additions.
class KitchenVoiceController {
  final String defaultLanguage;
  final ValueNotifier<VoiceControllerState> stateNotifier =
      ValueNotifier<VoiceControllerState>(VoiceControllerState.idle);
  final ValueNotifier<KitchenVoiceCommand?> lastCommandNotifier =
      ValueNotifier<KitchenVoiceCommand?>(null);
  final ValueNotifier<String> recognizedTextNotifier = ValueNotifier<String>('');

  // Callbacks for hands-free actions
  final VoidCallback? onNextStep;
  final VoidCallback? onPreviousStep;
  final VoidCallback? onRepeatStep;
  final void Function(int minutes)? onSetTimer;
  final VoidCallback? onPauseTimer;
  final VoidCallback? onResumeTimer;
  final void Function(String item)? onAddGrocery;
  final String Function()? onQueryWhistles;
  final VoidCallback? onQueryBoilingPoint;

  KitchenVoiceController({
    this.defaultLanguage = 'ne',
    this.onNextStep,
    this.onPreviousStep,
    this.onRepeatStep,
    this.onSetTimer,
    this.onPauseTimer,
    this.onResumeTimer,
    this.onAddGrocery,
    this.onQueryWhistles,
    this.onQueryBoilingPoint,
  });

  VoiceControllerState get state => stateNotifier.value;
  KitchenVoiceCommand? get lastCommand => lastCommandNotifier.value;

  /// Starts listening for hands-free kitchen voice commands.
  void startListening() {
    stateNotifier.value = VoiceControllerState.listening;
    recognizedTextNotifier.value = '';
  }

  /// Stops listening.
  void stopListening() {
    if (stateNotifier.value == VoiceControllerState.listening) {
      stateNotifier.value = VoiceControllerState.idle;
    }
  }

  /// Processes spoken transcription through the on-device `KitchenVoiceEngine`.
  KitchenVoiceCommand processUtterance(String utterance) {
    stateNotifier.value = VoiceControllerState.processing;
    recognizedTextNotifier.value = utterance;

    final command = KitchenVoiceEngine.parse(
      utterance,
      defaultLanguage: defaultLanguage,
    );

    lastCommandNotifier.value = command;

    if (command.intent != KitchenVoiceIntent.unknown) {
      stateNotifier.value = VoiceControllerState.recognized;
      _executeCommand(command);
    } else {
      stateNotifier.value = VoiceControllerState.error;
    }

    return command;
  }

  void _executeCommand(KitchenVoiceCommand command) {
    switch (command.intent) {
      case KitchenVoiceIntent.nextStep:
        onNextStep?.call();
        break;
      case KitchenVoiceIntent.previousStep:
        onPreviousStep?.call();
        break;
      case KitchenVoiceIntent.repeatStep:
        onRepeatStep?.call();
        break;
      case KitchenVoiceIntent.setTimer:
        if (command.timerMinutes != null) {
          onSetTimer?.call(command.timerMinutes!);
        }
        break;
      case KitchenVoiceIntent.pauseTimer:
        onPauseTimer?.call();
        break;
      case KitchenVoiceIntent.resumeTimer:
        onResumeTimer?.call();
        break;
      case KitchenVoiceIntent.addGrocery:
        if (command.groceryItem != null) {
          onAddGrocery?.call(command.groceryItem!);
        }
        break;
      case KitchenVoiceIntent.queryWhistles:
        onQueryWhistles?.call();
        break;
      case KitchenVoiceIntent.queryBoilingPoint:
        onQueryBoilingPoint?.call();
        break;
      case KitchenVoiceIntent.unknown:
        break;
    }
  }

  void dispose() {
    stateNotifier.dispose();
    lastCommandNotifier.dispose();
    recognizedTextNotifier.dispose();
  }
}
