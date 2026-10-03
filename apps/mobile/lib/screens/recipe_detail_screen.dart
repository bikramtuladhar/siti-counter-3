library;

import 'package:flutter/material.dart';
import 'package:kitchen_engine/nepali_calendar.dart';
import 'package:kitchen_engine/region_pack.dart';
import '../theme/nepali_typography.dart';
import '../theme/tokens.dart';

enum CooktopType {
  lpgGas,
  induction,
  infrared,
  electricCoil;

  String get id {
    switch (this) {
      case CooktopType.lpgGas:
        return 'lpg_gas';
      case CooktopType.induction:
        return 'induction';
      case CooktopType.infrared:
        return 'infrared';
      case CooktopType.electricCoil:
        return 'electric_coil';
    }
  }

  String get labelEn {
    switch (this) {
      case CooktopType.lpgGas:
        return 'LPG Gas';
      case CooktopType.induction:
        return 'Induction';
      case CooktopType.infrared:
        return 'Infrared';
      case CooktopType.electricCoil:
        return 'Electric Coil';
    }
  }

  String get labelNe {
    switch (this) {
      case CooktopType.lpgGas:
        return 'ग्यास चुलो (LPG)';
      case CooktopType.induction:
        return 'इन्डक्सन (Induction)';
      case CooktopType.infrared:
        return 'इन्फ्रारेड (Infrared)';
      case CooktopType.electricCoil:
        return 'हटर/क्वाइल (Electric)';
    }
  }

  String get heatGuidanceEn {
    switch (this) {
      case CooktopType.lpgGas:
        return 'Medium blue flame';
      case CooktopType.induction:
        return '1000W–1200W (simmer 800W)';
      case CooktopType.infrared:
        return 'Level 4–5 medium heat';
      case CooktopType.electricCoil:
        return 'Medium-high (Level 4)';
    }
  }

  String get heatGuidanceNe {
    switch (this) {
      case CooktopType.lpgGas:
        return 'मध्यम नीलो आगो';
      case CooktopType.induction:
        return '१०००–१२०० वाट (मन्द ८०० वाट)';
      case CooktopType.infrared:
        return 'स्तर ४–५ मध्यम ताप';
      case CooktopType.electricCoil:
        return 'मध्यम-कडा (स्तर ४)';
    }
  }

  int get whistleAdjustment {
    switch (this) {
      case CooktopType.electricCoil:
        return 1;
      case CooktopType.lpgGas:
      case CooktopType.induction:
      case CooktopType.infrared:
        return 0;
    }
  }
}

class RecipeDetailScreen extends StatefulWidget {
  final RegionRecipe recipe;
  final String currentLanguage;
  final CooktopType initialCooktop;
  final void Function(RegionRecipe recipe, int whistles, CooktopType cooktop)? onStartCooking;
  final void Function(RegionRecipe recipe, int servings)? onAddAllToGrocery;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.currentLanguage = 'ne',
    this.initialCooktop = CooktopType.lpgGas,
    this.onStartCooking,
    this.onAddAllToGrocery,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late int _servings;
  late CooktopType _selectedCooktop;
  final Set<int> _activeTimerStepIndices = {};

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.servings > 0 ? widget.recipe.servings : 4;
    _selectedCooktop = widget.initialCooktop;
  }

  double get _scalingFactor =>
      widget.recipe.servings > 0 ? _servings / widget.recipe.servings : 1.0;

  int get _effectiveWhistles {
    final base = widget.recipe.pressureCooker.recommendedWhistles;
    final altitudeOffset = widget.recipe.pressureCooker.altitudeWhistleOffsetKathmandu;
    final cooktopOffset = _selectedCooktop.whistleAdjustment;
    return base + altitudeOffset + cooktopOffset;
  }

  void _incrementServings() {
    if (_servings < 16) {
      setState(() {
        _servings++;
      });
    }
  }

  void _decrementServings() {
    if (_servings > 1) {
      setState(() {
        _servings--;
      });
    }
  }

  String _formatQuantity(double baseQuantity) {
    final scaled = baseQuantity * _scalingFactor;
    if (scaled == scaled.roundToDouble()) {
      final intVal = scaled.toInt();
      return _isNepali ? NepaliCalendar.toDevanagariDigits(intVal) : '$intVal';
    }
    final formattedDouble = scaled.toStringAsFixed(1);
    return _isNepali ? NepaliCalendar.toDevanagariDigits(formattedDouble) : formattedDouble;
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final title = _isNepali ? recipe.titleNe : recipe.titleEn;
    final subtitle = _isNepali ? recipe.titleEn : recipe.titleNe;

    return Scaffold(
      backgroundColor: SitiColors.warmWhite,
      appBar: AppBar(
        backgroundColor: SitiColors.warmWhite,
        elevation: 0,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: NepaliTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: SitiColors.dark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: SitiColors.dark),
            tooltip: 'Share Recipe',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isNepali ? 'रेसिपी लिङ्क कपी गरियो' : 'Recipe link copied'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Card
              _buildHeroCard(title, subtitle),
              const SizedBox(height: 16),

              // Human-Centric Servings Selector
              _buildServingsSelector(),
              const SizedBox(height: 16),

              // Cooktop Selector
              _buildCooktopSelector(),
              const SizedBox(height: 16),

              // Altitude Advisory Note
              if (recipe.pressureCooker.enabled) ...[
                _buildAltitudeAdvisory(),
                const SizedBox(height: 16),
              ],

              // Scaled Ingredients List
              _buildIngredientsCard(),
              const SizedBox(height: 16),

              // Titled Step List with Inline Timers & Target Siti
              _buildStepsSection(),
              const SizedBox(height: 16),

              // Nutrition & Cost Estimates
              _buildNutritionAndCostCard(),
              const SizedBox(height: 24),

              // Primary Action: Start Cooking
              _buildStartCookingButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(String title, String subtitle) {
    final recipe = widget.recipe;
    final totalMinutes = recipe.prepTimeMinutes + recipe.cookTimeMinutes;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      SitiColors.terracotta.withValues(alpha: 0.8),
                      SitiColors.terracotta,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.soup_kitchen_rounded, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: NepaliTypography.headlineSmall.copyWith(
                        color: SitiColors.dark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: NepaliTypography.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Meta Info Bar
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMetaTag(
                Icons.star_rounded,
                '${recipe.rating}',
                Colors.amber.shade800,
                Colors.amber.shade50,
              ),
              _buildMetaTag(
                Icons.timer_outlined,
                _isNepali
                    ? '${NepaliCalendar.toDevanagariDigits(totalMinutes)} मिनेट'
                    : '$totalMinutes mins',
                SitiColors.dark,
                Colors.grey.shade100,
              ),
              _buildMetaTag(
                Icons.bolt_rounded,
                _isNepali ? 'सजिलो (Easy)' : recipe.difficulty.toUpperCase(),
                SitiColors.freshGreen,
                Colors.green.shade50,
              ),
              if (recipe.pressureCooker.enabled)
                _buildMetaTag(
                  Icons.speed_rounded,
                  _isNepali
                      ? '${NepaliCalendar.toDevanagariDigits(_effectiveWhistles)} सिट्ठी'
                      : '$_effectiveWhistles whistles',
                  SitiColors.terracotta,
                  SitiColors.terracotta.withValues(alpha: 0.1),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaTag(IconData icon, String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: NepaliTypography.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServingsSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SitiColors.terracotta.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline_rounded,
                color: SitiColors.terracotta, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali ? 'कति जनाका लागि खाना बनाउँदै हुनुहुन्छ?' : 'How many people are eating?',
                  style: NepaliTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SitiColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isNepali
                      ? 'मात्रा र सामग्री स्वतः समायोजन हुन्छन्'
                      : 'Ingredient amounts scale dynamically',
                  style: NepaliTypography.bodySmall.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Stepper
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                onPressed: _decrementServings,
                icon: const Icon(Icons.remove_rounded, size: 18),
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: EdgeInsets.zero,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 40),
                alignment: Alignment.center,
                child: Text(
                  _isNepali
                      ? '${NepaliCalendar.toDevanagariDigits(_servings)} जना'
                      : '$_servings',
                  style: NepaliTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SitiColors.terracotta,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _incrementServings,
                icon: const Icon(Icons.add_rounded, size: 18),
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCooktopSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.heat_pump_rounded, size: 20, color: SitiColors.terracotta),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isNepali ? 'प्रयोग गरिने चुलो (Cooktop Type)' : 'Cooktop Type',
                  style: NepaliTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SitiColors.dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Cooktop Options
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CooktopType.values.map((cooktop) {
              final isSelected = cooktop == _selectedCooktop;
              final label = _isNepali ? cooktop.labelNe : cooktop.labelEn;

              return ChoiceChip(
                selected: isSelected,
                label: Text(
                  label,
                  style: NepaliTypography.labelSmall.copyWith(
                    color: isSelected ? Colors.white : SitiColors.dark,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                selectedColor: SitiColors.terracotta,
                backgroundColor: Colors.grey.shade100,
                side: BorderSide(
                  color: isSelected ? SitiColors.terracotta : Colors.grey.shade300,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedCooktop = cooktop;
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Cooktop guidance card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates_outlined,
                    size: 18, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isNepali
                        ? 'ताप मार्गदर्शन: ${_selectedCooktop.heatGuidanceNe}'
                        : 'Heat guidance: ${_selectedCooktop.heatGuidanceEn}',
                    style: NepaliTypography.bodySmall.copyWith(
                      color: Colors.brown.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAltitudeAdvisory() {
    final baseWhistles = widget.recipe.pressureCooker.recommendedWhistles;
    final altitudeOffset = widget.recipe.pressureCooker.altitudeWhistleOffsetKathmandu;
    final totalAtAltitude = baseWhistles + altitudeOffset;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.terrain_rounded, size: 20, color: Colors.blue.shade800),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNepali
                      ? 'काठमाडौँ उचाइ सल्लाह (१,४०० मिटर):'
                      : 'Kathmandu Altitude Advisory (1,400 m):',
                  style: NepaliTypography.titleSmall.copyWith(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isNepali
                      ? 'उचाइका कारण पानी ९५.३°C मा उम्लन्छ। बेस $baseWhistles सिट्ठीमा +$altitudeOffset सिट्ठी (जम्मा $totalAtAltitude सिट्ठी) आवश्यक पर्छ।'
                      : 'At 1,400 m, water boils at 95.3°C. Requires +$altitudeOffset whistle ($totalAtAltitude whistles instead of $baseWhistles).',
                  style: NepaliTypography.bodySmall.copyWith(
                    color: Colors.blue.shade900,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isNepali ? 'आवश्यक सामग्रीहरू' : 'Required Ingredients',
                style: NepaliTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SitiColors.dark,
                ),
              ),
              Text(
                _isNepali
                    ? '(${NepaliCalendar.toDevanagariDigits(_servings)} जनाका लागि)'
                    : '(for $_servings people)',
                style: NepaliTypography.bodySmall.copyWith(
                  color: SitiColors.terracotta,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.recipe.ingredients.length,
            separatorBuilder: (context, index) => const Divider(height: 12),
            itemBuilder: (context, index) {
              final item = widget.recipe.ingredients[index];
              final scaledQty = _formatQuantity(item.quantity);
              final unit = item.unit;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: SitiColors.terracotta),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.ingredientId.replaceAll('_', ' '),
                        style: NepaliTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: SitiColors.dark,
                        ),
                      ),
                    ),
                    Text(
                      '$scaledQty $unit',
                      style: NepaliTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: SitiColors.dark,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Add all to grocery list button
          OutlinedButton.icon(
            onPressed: () {
              if (widget.onAddAllToGrocery != null) {
                widget.onAddAllToGrocery!(widget.recipe, _servings);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isNepali
                        ? 'सबै सामग्री किराना सूचीमा थपियो'
                        : 'Added all ingredients to grocery list',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.playlist_add_rounded, size: 18),
            label: Text(
              _isNepali ? 'सबै सामग्री सूचीमा थप्नुहोस्' : 'Add all to grocery list',
              style: NepaliTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: SitiColors.dark,
              side: BorderSide(color: Colors.grey.shade300),
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsSection() {
    final steps = widget.recipe.steps;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isNepali ? 'पकाउने चरणहरू' : 'Cooking Steps',
            style: NepaliTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: SitiColors.dark,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final step = steps[index];
              final instruction =
                  _isNepali ? step.instructionNe : step.instructionEn;
              final isTimerActive = _activeTimerStepIndices.contains(index);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: SitiColors.terracotta,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _isNepali
                                  ? NepaliCalendar.toDevanagariDigits(step.stepNumber)
                                  : '${step.stepNumber}',
                              style: NepaliTypography.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isNepali
                              ? 'चरण ${NepaliCalendar.toDevanagariDigits(step.stepNumber)}'
                              : 'Step ${step.stepNumber}',
                          style: NepaliTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SitiColors.dark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      instruction,
                      style: NepaliTypography.bodyMedium.copyWith(
                        color: SitiColors.dark,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Step badges: Timer & Whistles
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (step.timerMinutes != null)
                          ActionChip(
                            avatar: Icon(
                              isTimerActive ? Icons.timer_rounded : Icons.timer_outlined,
                              size: 16,
                              color: isTimerActive ? Colors.white : SitiColors.dark,
                            ),
                            label: Text(
                              _isNepali
                                  ? '${NepaliCalendar.toDevanagariDigits(step.timerMinutes!)} मिनेट'
                                  : '${step.timerMinutes} mins',
                              style: NepaliTypography.labelSmall.copyWith(
                                color: isTimerActive ? Colors.white : SitiColors.dark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: isTimerActive ? SitiColors.terracotta : Colors.white,
                            side: BorderSide(
                              color: isTimerActive ? SitiColors.terracotta : Colors.grey.shade300,
                            ),
                            onPressed: () {
                              setState(() {
                                if (isTimerActive) {
                                  _activeTimerStepIndices.remove(index);
                                } else {
                                  _activeTimerStepIndices.add(index);
                                }
                              });
                            },
                          ),
                        if (step.whistles != null)
                          Chip(
                            avatar: const Icon(Icons.speed_rounded,
                                size: 16, color: SitiColors.terracotta),
                            label: Text(
                              _isNepali
                                  ? '${NepaliCalendar.toDevanagariDigits(step.whistles!)} सिट्ठी'
                                  : '${step.whistles} whistles',
                              style: NepaliTypography.labelSmall.copyWith(
                                color: SitiColors.terracotta,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            backgroundColor: SitiColors.terracotta.withValues(alpha: 0.1),
                            side: BorderSide.none,
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionAndCostCard() {
    final calories = widget.recipe.caloriesPerServing;
    final costPerServing = widget.recipe.costEstimateNpr;
    final totalCost = costPerServing * _servings;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isNepali ? 'पोषण र लागत अनुमान' : 'Nutrition & Cost Estimates',
            style: NepaliTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: SitiColors.dark,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNepali ? 'प्रति भाग क्यालोरी' : 'Per Portion',
                        style: NepaliTypography.labelSmall.copyWith(
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isNepali
                            ? '${NepaliCalendar.toDevanagariDigits(calories)} क्यालोरी'
                            : '$calories kcal',
                        style: NepaliTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNepali ? 'अनुमानित लागत (जम्मा)' : 'Estimated Cost',
                        style: NepaliTypography.labelSmall.copyWith(
                          color: Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isNepali
                            ? 'रु ${NepaliCalendar.toDevanagariDigits(totalCost)}'
                            : 'NPR $totalCost',
                        style: NepaliTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartCookingButton() {
    return ElevatedButton.icon(
      onPressed: () {
        if (widget.onStartCooking != null) {
          widget.onStartCooking!(widget.recipe, _effectiveWhistles, _selectedCooktop);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isNepali
                    ? 'सिट्ठी काउन्टर सुरु भयो: $_effectiveWhistles सिट्ठी'
                    : 'Started Siti Counter for $_effectiveWhistles whistles',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
      label: Text(
        _isNepali ? 'सिट्ठी काउन्टर सुरु गर्नुहोस्' : 'Start Siti Counter',
        style: NepaliTypography.titleMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: SitiColors.terracotta,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
    );
  }
}
