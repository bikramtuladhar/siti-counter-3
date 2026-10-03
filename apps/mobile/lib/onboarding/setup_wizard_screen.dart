import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'onboarding_state.dart';

class SetupWizardScreen extends StatefulWidget {
  final OnboardingPreferences initialPrefs;
  final ValueChanged<OnboardingPreferences> onComplete;
  final VoidCallback onBack;

  const SetupWizardScreen({
    super.key,
    required this.initialPrefs,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0;
  late OnboardingPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.initialPrefs;
  }

  bool get _isNepali => _prefs.language == 'ne';

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
    } else {
      widget.onComplete(_prefs);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      widget.onBack();
    }
  }

  Widget _buildStepIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isNepali ? 'प्रश्न ${_currentStep + 1} / ५' : 'Question ${_currentStep + 1} of 5',
              style: NepaliTypography.labelLarge.copyWith(
                color: SitiColors.terracotta,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${((_currentStep + 1) * 20)}%',
              style: NepaliTypography.bodyMedium.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 5.0,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(SitiColors.terracotta),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // --- Step 1: Region / Elevation ---
  Widget _buildQuestion1Region() {
    final regions = [
      {
        'id': 'nepal-bagmati',
        'titleNe': 'नेपाल - बागमती प्रदेश (काठमाडौँ उपत्यका)',
        'titleEn': 'Nepal - Bagmati Province (Kathmandu Valley)',
        'subtitle': '१,४०० मिटर उचाइ • पाउ/धार्नी/माना • ६ ऋतु',
      },
      {
        'id': 'nepal-terai',
        'titleNe': 'नेपाल - तराई मधेस',
        'titleEn': 'Nepal - Terai Region',
        'subtitle': '१००-३०० मिटर उचाइ • के.जी./ग्राम • तराई ऋतु',
      },
      {
        'id': 'global-metric',
        'titleNe': 'अन्तर्राष्ट्रिय / डायस्पोरा',
        'titleEn': 'International / Diaspora',
        'subtitle': 'Standard Sea-Level • Metric & Cups',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isNepali ? 'तपाईं कहाँ पकाउनुहुन्छ?' : 'Where do you cook?',
          style: NepaliTypography.headlineMedium.copyWith(color: SitiColors.dark),
        ),
        const SizedBox(height: 6),
        Text(
          _isNepali
              ? 'उचाइअनुसार पानी उम्लने तापक्रम र प्रेसर कुकरको सिट्ठी गणना फरक पर्छ।'
              : 'Altitude affects water boiling points and pressure cooker timing.',
          style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        ...regions.map((reg) {
          final isSelected = _prefs.regionPackId == reg['id'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                setState(() {
                  _prefs.regionPackId = reg['id']!;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? SitiColors.terracotta.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? SitiColors.terracotta : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      color: isSelected ? SitiColors.terracotta : Colors.grey,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isNepali ? reg['titleNe']! : reg['titleEn']!,
                            style: NepaliTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reg['subtitle']!,
                            style: NepaliTypography.bodyMedium.copyWith(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- Step 2: Language ---
  Widget _buildQuestion2Language() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isNepali ? 'कुन भाषा मन पराउनुहुन्छ?' : 'What language do you prefer?',
          style: NepaliTypography.headlineMedium.copyWith(color: SitiColors.dark),
        ),
        const SizedBox(height: 6),
        Text(
          _isNepali ? 'तपाईंले पछि सेटिङबाट जुनसुकै बेला फेर्न सक्नुहुन्छ।' : 'You can switch anytime in settings.',
          style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        _buildRadioOption(
          id: 'ne',
          currentVal: _prefs.language,
          title: 'नेपाली (Devanagari)',
          subtitle: 'परम्परागत नेपाली अंक, ६ ऋतु र स्थानीय नाम',
          onSelect: (v) => setState(() => _prefs.language = v),
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          id: 'en',
          currentVal: _prefs.language,
          title: 'English',
          subtitle: 'English recipe instructions with Nepali ingredient terms',
          onSelect: (v) => setState(() => _prefs.language = v),
        ),
      ],
    );
  }

  // --- Step 3: Stove Type ---
  Widget _buildQuestion3Stove() {
    final stoves = [
      {'id': 'lpg_gas', 'nameNe': 'ग्यास चुलो (LPG Cylinder)', 'nameEn': 'LPG Gas Stove', 'icon': Icons.local_fire_department_rounded},
      {'id': 'induction', 'nameNe': 'इन्डक्सन चुलो (Induction Cooktop)', 'nameEn': 'Induction Cooktop', 'icon': Icons.flash_on_rounded},
      {'id': 'electric_coil', 'nameNe': 'विद्युतीय हिटर (Electric Stove)', 'nameEn': 'Electric Coil Stove', 'icon': Icons.power_rounded},
      {'id': 'biomass_wood', 'nameNe': 'दाउराको चुलो (Firewood / Biomass)', 'nameEn': 'Wood Fire / Biomass', 'icon': Icons.forest_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isNepali ? 'तपाईंको मुख्य चुलो कुन हो?' : 'What do you cook on?',
          style: NepaliTypography.headlineMedium.copyWith(color: SitiColors.dark),
        ),
        const SizedBox(height: 6),
        Text(
          _isNepali ? 'चुलोको तापक्रम उत्सर्जनअनुसार सिट्ठी समय समायोजन हुन्छ।' : 'Heat response curves calibrate whistle detection timing.',
          style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        ...stoves.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRadioOption(
            id: s['id'] as String,
            currentVal: _prefs.stoveType,
            title: _isNepali ? (s['nameNe'] as String) : (s['nameEn'] as String),
            icon: s['icon'] as IconData,
            onSelect: (v) => setState(() => _prefs.stoveType = v),
          ),
        )),
      ],
    );
  }

  // --- Step 4: Household Size ---
  Widget _buildQuestion4Household() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isNepali ? 'घरमा कति जना खाना खानुहुन्छ?' : 'Who eats at home?',
          style: NepaliTypography.headlineMedium.copyWith(color: SitiColors.dark),
        ),
        const SizedBox(height: 6),
        Text(
          _isNepali ? 'यसले दाल, भात र तरकारीको ठिक्क परिमाण नाप्न मद्दत गर्छ।' : 'Used to accurately scale recipe quantities and grocery lists.',
          style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 24),
        _buildCounterRow(
          title: _isNepali ? 'वयस्कहरू (Adults)' : 'Adults',
          count: _prefs.adultsCount,
          onChanged: (val) => setState(() => _prefs.adultsCount = val),
          min: 1,
        ),
        const Divider(height: 32),
        _buildCounterRow(
          title: _isNepali ? 'बालबालिका (Children)' : 'Children',
          count: _prefs.childrenCount,
          onChanged: (val) => setState(() => _prefs.childrenCount = val),
          min: 0,
        ),
        const Divider(height: 32),
        _buildCounterRow(
          title: _isNepali ? 'ज्येष्ठ नागरिक (Elders)' : 'Elders',
          count: _prefs.eldersCount,
          onChanged: (val) => setState(() => _prefs.eldersCount = val),
          min: 0,
        ),
      ],
    );
  }

  // --- Step 5: Dietary Rules ---
  Widget _buildQuestion5Dietary() {
    final rules = [
      {'id': 'strict_vegetarian', 'nameNe': 'शुद्ध शाकाहारी (Strict Vegetarian)', 'nameEn': 'Strict Vegetarian'},
      {'id': 'no_onion_garlic', 'nameNe': 'लसुन र प्याज नखाने (No Onion / Garlic)', 'nameEn': 'No Onion or Garlic'},
      {'id': 'non_veg', 'nameNe': 'मासु तथा सबै खाने (Non-Vegetarian)', 'nameEn': 'Non-Vegetarian'},
      {'id': 'gluten_free', 'nameNe': 'गहुँ / ग्लुटेन बिना (Gluten-Free)', 'nameEn': 'Gluten-Free'},
      {'id': 'dairy_free', 'nameNe': 'दूधजन्य परिकार नखाने (Dairy-Free)', 'nameEn': 'Dairy-Free / Lactose-Free'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isNepali ? 'खानासम्बन्धी कुनै नियम वा बन्देज?' : 'Any food rules or allergies?',
          style: NepaliTypography.headlineMedium.copyWith(color: SitiColors.dark),
        ),
        const SizedBox(height: 6),
        Text(
          _isNepali ? 'तपाईंको तालिकामा नखाने परिकार स्वतः हटाइन्छ।' : 'We will filter out recipes that violate your household rules.',
          style: NepaliTypography.bodyMedium.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        ...rules.map((rule) {
          final isChecked = _prefs.dietaryRules.contains(rule['id']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isChecked) {
                    _prefs.dietaryRules.remove(rule['id']!);
                  } else {
                    _prefs.dietaryRules.add(rule['id']!);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isChecked ? SitiColors.terracotta.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isChecked ? SitiColors.terracotta : Colors.grey.shade300,
                    width: isChecked ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      color: isChecked ? SitiColors.terracotta : Colors.grey,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _isNepali ? rule['nameNe']! : rule['nameEn']!,
                        style: NepaliTypography.titleMedium.copyWith(
                          fontSize: 15,
                          fontWeight: isChecked ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRadioOption({
    required String id,
    required String currentVal,
    required String title,
    String? subtitle,
    IconData? icon,
    required ValueChanged<String> onSelect,
  }) {
    final isSelected = currentVal == id;
    return InkWell(
      onTap: () => onSelect(id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? SitiColors.terracotta.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? SitiColors.terracotta : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: isSelected ? SitiColors.terracotta : Colors.grey.shade700),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: NepaliTypography.titleMedium.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: NepaliTypography.bodyMedium.copyWith(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? SitiColors.terracotta : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterRow({
    required String title,
    required int count,
    required ValueChanged<int> onChanged,
    required int min,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: NepaliTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: count > min ? () => onChanged(count - 1) : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              iconSize: 32,
              color: count > min ? SitiColors.terracotta : Colors.grey.shade400,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$count',
                style: NepaliTypography.titleMedium.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: count < 15 ? () => onChanged(count + 1) : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
              iconSize: 32,
              color: count < 15 ? SitiColors.terracotta : Colors.grey.shade400,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: SitiColors.warmWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: SitiColors.dark),
          onPressed: _prevStep,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Builder(
                    builder: (context) {
                      switch (_currentStep) {
                        case 0:
                          return _buildQuestion1Region();
                        case 1:
                          return _buildQuestion2Language();
                        case 2:
                          return _buildQuestion3Stove();
                        case 3:
                          return _buildQuestion4Household();
                        case 4:
                          return _buildQuestion5Dietary();
                        default:
                          return const SizedBox.shrink();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SitiColors.terracotta,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentStep == 4
                        ? (_isNepali ? 'किचन तयार गर्नुहोस्' : 'Generate My Kitchen')
                        : (_isNepali ? 'अगाडि बढ्नुहोस्' : 'Continue'),
                    style: NepaliTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
