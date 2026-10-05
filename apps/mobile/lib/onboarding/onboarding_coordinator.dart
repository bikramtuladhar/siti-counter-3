import 'package:flutter/material.dart';
import '../settings/social_auth_service.dart';
import '../settings/social_sign_in_sheet.dart';
import 'onboarding_state.dart';
import 'welcome_tour_screen.dart';
import 'setup_wizard_screen.dart';
import 'kitchen_ready_screen.dart';

enum OnboardingStep {
  tour,
  wizard,
  kitchenReady,
}

class OnboardingCoordinator extends StatefulWidget {
  final ValueChanged<OnboardingPreferences> onComplete;

  /// Social sign-in, offered once the kitchen is ready.
  ///
  /// Omitted in tests and in builds without provider SDKs, which hides the entry point
  /// rather than failing when tapped.
  final SocialSignInService? signInService;

  /// Raised after a successful sign-in, carrying the account's household so the caller can
  /// re-point its caches and stop treating the device as a guest.
  final ValueChanged<SocialSignInResult>? onSignedIn;

  const OnboardingCoordinator({
    super.key,
    required this.onComplete,
    this.signInService,
    this.onSignedIn,
  });

  @override
  State<OnboardingCoordinator> createState() => _OnboardingCoordinatorState();
}

class _OnboardingCoordinatorState extends State<OnboardingCoordinator> {
  OnboardingStep _step = OnboardingStep.tour;
  final OnboardingPreferences _prefs = OnboardingPreferences();

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case OnboardingStep.tour:
        return WelcomeTourScreen(
          preferNepali: _prefs.isNepali,
          onLanguageChanged: (preferNepali) {
            setState(() {
              _prefs.language = preferNepali ? 'ne' : 'en';
            });
          },
          onFinish: () {
            setState(() {
              _step = OnboardingStep.wizard;
            });
          },
        );

      case OnboardingStep.wizard:
        return SetupWizardScreen(
          initialPrefs: _prefs,
          onBack: () {
            setState(() {
              _step = OnboardingStep.tour;
            });
          },
          onComplete: (completedPrefs) {
            setState(() {
              _prefs.regionPackId = completedPrefs.regionPackId;
              _prefs.language = completedPrefs.language;
              _prefs.stoveTypes = completedPrefs.stoveTypes;
              _prefs.adultsCount = completedPrefs.adultsCount;
              _prefs.childrenCount = completedPrefs.childrenCount;
              _prefs.eldersCount = completedPrefs.eldersCount;
              _prefs.dietaryRules = completedPrefs.dietaryRules;
              _step = OnboardingStep.kitchenReady;
            });
          },
        );

      case OnboardingStep.kitchenReady:
        return KitchenReadyScreen(
          prefs: _prefs,
          onStartCooking: () {
            widget.onComplete(_prefs);
          },
          onCreateAccount: widget.signInService == null
              ? null
              : () => _openSignIn(),
        );
    }
  }

  Future<void> _openSignIn() async {
    final service = widget.signInService;
    if (service == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SocialSignInSheet(
        signInService: service,
        preferNepali: _prefs.isNepali,
        onLanguageChanged: (preferNepali) {
          if (!mounted) return;
          setState(() {
            _prefs.language = preferNepali ? 'ne' : 'en';
          });
        },
        onSignedIn: (result) {
          widget.onSignedIn?.call(result);
          Navigator.of(ctx).pop();
        },
        onContinueAsGuest: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}
