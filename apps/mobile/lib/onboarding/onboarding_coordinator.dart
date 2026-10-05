import 'package:flutter/material.dart';
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

  const OnboardingCoordinator({
    super.key,
    required this.onComplete,
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
        );
    }
  }
}
