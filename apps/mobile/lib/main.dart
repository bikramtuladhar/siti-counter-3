import 'package:flutter/material.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import 'onboarding/onboarding_coordinator.dart';
import 'onboarding/onboarding_state.dart';
import 'theme/tokens.dart';
import 'theme/nepali_typography.dart';
import 'widgets/six_ritus_indicator.dart';

void main() {
  runApp(const SitiCounterApp());
}

class SitiCounterApp extends StatefulWidget {
  const SitiCounterApp({super.key});

  @override
  State<SitiCounterApp> createState() => _SitiCounterAppState();
}

class _SitiCounterAppState extends State<SitiCounterApp> {
  OnboardingPreferences? _userPreferences;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Siti Counter 3.0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SitiColors.terracotta,
          primary: SitiColors.terracotta,
          surface: SitiColors.warmWhite,
        ),
        textTheme: NepaliTypography.createTextTheme(SitiColors.dark),
      ),
      home: _userPreferences == null
          ? OnboardingCoordinator(
              onComplete: (prefs) {
                setState(() {
                  _userPreferences = prefs;
                });
              },
            )
          : KitchenHomeScreen(
              preferences: _userPreferences!,
              onResetOnboarding: () {
                setState(() {
                  _userPreferences = null;
                });
              },
            ),
    );
  }
}

class KitchenHomeScreen extends StatefulWidget {
  final OnboardingPreferences preferences;
  final VoidCallback onResetOnboarding;

  const KitchenHomeScreen({
    super.key,
    required this.preferences,
    required this.onResetOnboarding,
  });

  @override
  State<KitchenHomeScreen> createState() => _KitchenHomeScreenState();
}

class _KitchenHomeScreenState extends State<KitchenHomeScreen> {
  int _whistleCount = 0;
  bool _isListening = false;

  bool get _isNepali => widget.preferences.language == 'ne';

  void _incrementWhistle() {
    setState(() {
      _whistleCount++;
    });
  }

  void _decrementWhistle() {
    if (_whistleCount > 0) {
      setState(() {
        _whistleCount--;
      });
    }
  }

  void _resetWhistle() {
    setState(() {
      _whistleCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Current date in BS (approx 2081 Ashwin 15)
    const todayBs = BsDate(year: 2081, month: 7, day: 15);

    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: SitiColors.warmWhite,
        elevation: 0,
        title: Text(
          'Siti Counter 3.0',
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: SitiColors.dark,
          ),
        ),
        actions: [
          // Guest Mode Indicator Badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade700, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 14, color: Colors.amber.shade900),
                const SizedBox(width: 4),
                Text(
                  _isNepali ? 'अतिथि (Guest)' : 'Guest Mode',
                  style: NepaliTypography.labelLarge.copyWith(
                    color: Colors.amber.shade900,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: SitiColors.dark),
            tooltip: 'Setup Wizard',
            onPressed: widget.onResetOnboarding,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Six Ritus Season Indicator
              SixRitusIndicator(
                currentDate: todayBs,
                preferNepali: _isNepali,
              ),
              const SizedBox(height: 24),

              // Whistle Counter Hero Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      _isNepali ? 'सिट्ठी संख्या' : 'Whistle Count',
                      style: NepaliTypography.titleMedium.copyWith(
                        color: Colors.grey.shade600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Massive Counter Display
                    Text(
                      _isNepali
                          ? NepaliCalendar.toDevanagariDigits(_whistleCount)
                          : '$_whistleCount',
                      style: SitiTypography.counterArmsLengthStyle.copyWith(
                        color: SitiColors.terracotta,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      _isListening
                          ? (_isNepali ? 'ध्वनि सुन्दैछ... (Listening)' : 'Listening for whistle...')
                          : (_isNepali ? 'स्ट्यान्डबाइ (Standby)' : 'Standby Mode'),
                      style: NepaliTypography.bodyMedium.copyWith(
                        color: _isListening ? SitiColors.freshGreen : Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Manual Adjustment Buttons
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        IconButton.filledTonal(
                          onPressed: _decrementWhistle,
                          icon: const Icon(Icons.remove_rounded),
                          iconSize: 28,
                          tooltip: '-1 Whistle',
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _isListening = !_isListening;
                            });
                          },
                          icon: Icon(
                            _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                            size: 20,
                          ),
                          label: Text(_isListening ? 'Stop' : 'Start Auto-Listen'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _isListening ? SitiColors.alert : SitiColors.terracotta,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _incrementWhistle,
                          icon: const Icon(Icons.add_rounded),
                          iconSize: 28,
                          tooltip: '+1 Whistle',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reset Button
              Center(
                child: TextButton.icon(
                  onPressed: _resetWhistle,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(_isNepali ? 'सिट्ठी रिसेट' : 'Reset Counter'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
