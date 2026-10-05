import 'package:flutter/material.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import '../theme/tokens.dart';
import '../theme/nepali_typography.dart';
import 'community_badge.dart';
import 'community_service.dart';

class CommunityRecipeFormScreen extends StatefulWidget {
  final CommunityService service;
  final String currentLanguage;
  final String? initialCuisine;

  const CommunityRecipeFormScreen({
    super.key,
    required this.service,
    this.currentLanguage = 'ne',
    this.initialCuisine,
  });

  @override
  State<CommunityRecipeFormScreen> createState() => _CommunityRecipeFormScreenState();
}

class _CommunityRecipeFormScreenState extends State<CommunityRecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleNeController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _culturalStoryController = TextEditingController();
  final _authorController = TextEditingController(text: 'सुनिता श्रेष्ठ');

  String _cuisine = 'Newa';
  int _servings = 4;
  final int _prepMinutes = 15;
  int _cookMinutes = 25;
  int _whistles = 3;

  final List<CommunityIngredientItem> _ingredients = [];
  final List<CommunityRecipeStepItem> _steps = [];

  // Temporary controllers for adding ingredients
  final _ingNameNeController = TextEditingController();
  final _ingNameEnController = TextEditingController();
  final _ingQtyController = TextEditingController(text: '200');
  final String _ingUnit = 'g';

  // Temporary controller for adding steps
  final _stepInstructionNeController = TextEditingController();
  final _stepInstructionEnController = TextEditingController();
  bool _stepIsWhistle = false;

  CommunityContribution? _lastSubmission;
  bool _isSubmitting = false;

  bool get _isNepali => widget.currentLanguage == 'ne';

  @override
  void initState() {
    super.initState();
    if (widget.initialCuisine != null) {
      _cuisine = widget.initialCuisine!;
    }
  }

  @override
  void dispose() {
    _titleNeController.dispose();
    _titleEnController.dispose();
    _culturalStoryController.dispose();
    _authorController.dispose();
    _ingNameNeController.dispose();
    _ingNameEnController.dispose();
    _ingQtyController.dispose();
    _stepInstructionNeController.dispose();
    _stepInstructionEnController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    if (_ingNameNeController.text.trim().isEmpty &&
        _ingNameEnController.text.trim().isEmpty) {
      return;
    }

    final qty = double.tryParse(_ingQtyController.text.trim()) ?? 100.0;
    setState(() {
      _ingredients.add(
        CommunityIngredientItem(
          nameNe: _ingNameNeController.text.trim().isNotEmpty
              ? _ingNameNeController.text.trim()
              : _ingNameEnController.text.trim(),
          nameEn: _ingNameEnController.text.trim().isNotEmpty
              ? _ingNameEnController.text.trim()
              : _ingNameNeController.text.trim(),
          quantity: qty,
          unit: _ingUnit,
        ),
      );
      _ingNameNeController.clear();
      _ingNameEnController.clear();
      _ingQtyController.text = '200';
    });
  }

  void _addStep() {
    if (_stepInstructionNeController.text.trim().isEmpty &&
        _stepInstructionEnController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _steps.add(
        CommunityRecipeStepItem(
          order: _steps.length + 1,
          instructionNe: _stepInstructionNeController.text.trim().isNotEmpty
              ? _stepInstructionNeController.text.trim()
              : _stepInstructionEnController.text.trim(),
          instructionEn: _stepInstructionEnController.text.trim().isNotEmpty
              ? _stepInstructionEnController.text.trim()
              : _stepInstructionNeController.text.trim(),
          isWhistleStep: _stepIsWhistle,
          whistles: _stepIsWhistle ? _whistles : null,
        ),
      );
      _stepInstructionNeController.clear();
      _stepInstructionEnController.clear();
      _stepIsWhistle = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNepali
              ? 'कृपया कम्तिमा एउटा सामग्री थप्नुहोस्'
              : 'Please add at least one ingredient'),
        ),
      );
      return;
    }

    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNepali
              ? 'कृपया कम्तिमा एउटा पकाउने विधि थप्नुहोस्'
              : 'Please add at least one cooking step'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = CommunityRecipePayload(
      titleNe: _titleNeController.text.trim(),
      titleEn: _titleEnController.text.trim().isNotEmpty
          ? _titleEnController.text.trim()
          : _titleNeController.text.trim(),
      cuisine: _cuisine,
      servings: _servings,
      prepTimeMinutes: _prepMinutes,
      cookTimeMinutes: _cookMinutes,
      whistleCount: _whistles,
      ingredients: List.from(_ingredients),
      steps: List.from(_steps),
      authorHouseholdId: 'hh_current_user',
      authorDisplayName: _authorController.text.trim().isNotEmpty
          ? _authorController.text.trim()
          : 'Siti Cook',
      culturalStory: _culturalStoryController.text.trim().isNotEmpty
          ? _culturalStoryController.text.trim()
          : null,
    );

    final result = await widget.service.submitRecipe(payload);

    setState(() {
      _lastSubmission = result;
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNepali ? 'सामुदायिक रेसिपी योगदान' : 'Contribute Recipe',
          style: NepaliTypography.titleMedium.copyWith(color: SitiColors.dark),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SitiColors.dark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Moderation Result Banner if just submitted
              if (_lastSubmission != null) ...[
                _buildSubmissionResultBanner(_lastSubmission!),
                const SizedBox(height: 20),
              ],

              // Info card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_outlined, color: Colors.amber.shade900),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isNepali
                            ? 'तपाईंको पारिवारिक परिकार अरूलाई सिकाउनुहोस्। सुरक्षित र पूर्ण रेसिपीलाई "सामुदायिक" वा "प्रमाणित" ब्याज प्रदान गरिन्छ।'
                            : 'Share your family recipes with the community. Safe recipes receive Community or Verified badges.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title Ne
              TextFormField(
                key: const Key('recipe_title_ne_input'),
                controller: _titleNeController,
                decoration: InputDecoration(
                  labelText: _isNepali ? 'रेसिपीको नाम (नेपाली)*' : 'Recipe Title (Nepali)*',
                  hintText: 'उदा: क्वाँटी, तामा आलु, थकाली दाल',
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if ((val == null || val.trim().isEmpty) &&
                      _titleEnController.text.trim().isEmpty) {
                    return _isNepali ? 'नाम आवश्यक छ' : 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Title En
              TextFormField(
                key: const Key('recipe_title_en_input'),
                controller: _titleEnController,
                decoration: InputDecoration(
                  labelText: _isNepali ? 'रेसिपीको नाम (अंग्रेजी)' : 'Recipe Title (English)',
                  hintText: 'e.g. Kwati Sprouted Bean Soup',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              // Cuisine & Servings Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const Key('cuisine_dropdown'),
                      isExpanded: true,
                      initialValue: _cuisine,
                      decoration: InputDecoration(
                        labelText: _isNepali ? 'परिकार शैली (Cuisine)' : 'Cuisine',
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Newa', child: Text('Newa (नेवाः)')),
                        DropdownMenuItem(value: 'Thakali', child: Text('Thakali (थकाली)')),
                        DropdownMenuItem(value: 'Mithila', child: Text('Mithila (मिथिला)')),
                        DropdownMenuItem(value: 'Khas/Parbate', child: Text('Khas/Parbate (पर्वते)')),
                        DropdownMenuItem(value: 'Sherpa', child: Text('Sherpa (शेर्पा)')),
                        DropdownMenuItem(value: 'Nepali-Modern', child: Text('Nepali Modern')),
                      ],
                      onChanged: (val) => setState(() => _cuisine = val ?? 'Newa'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('servings_input'),
                      initialValue: _servings.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _isNepali ? 'भाग (Servings)' : 'Servings',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => _servings = int.tryParse(val) ?? 4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Timing & Whistle Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('cook_time_input'),
                      initialValue: _cookMinutes.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _isNepali ? 'पकाउने समय (मिनेट)' : 'Cook (mins)',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => _cookMinutes = int.tryParse(val) ?? 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('whistle_count_input'),
                      initialValue: _whistles.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _isNepali ? 'सिट्ठी (Whistles)' : 'Whistles',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => _whistles = int.tryParse(val) ?? 3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Ingredients Section
              Text(
                _isNepali ? 'सामग्रीहरू (Ingredients)' : 'Ingredients',
                style: NepaliTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Ingredient List
              if (_ingredients.isEmpty)
                Text(
                  _isNepali ? 'कुनै सामग्री थपिएको छैन' : 'No ingredients added yet',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                )
              else
                ..._ingredients.map((ing) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.check_circle_outline, color: SitiColors.terracotta, size: 18),
                      title: Text('${ing.nameNe} (${ing.nameEn})'),
                      trailing: Text('${ing.quantity} ${ing.unit}'),
                    )),

              const SizedBox(height: 8),
              // Add ingredient inputs
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      key: const Key('ing_name_input'),
                      controller: _ingNameNeController,
                      decoration: InputDecoration(
                        hintText: _isNepali ? 'सामग्रीको नाम' : 'Ingredient name',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('ing_qty_input'),
                      controller: _ingQtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Qty', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('add_ingredient_btn'),
                    icon: Icon(Icons.add_circle, color: SitiColors.terracotta),
                    onPressed: _addIngredient,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Steps Section
              Text(
                _isNepali ? 'पकाउने चरणहरू (Cooking Steps)' : 'Cooking Steps',
                style: NepaliTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (_steps.isEmpty)
                Text(
                  _isNepali ? 'कुनै चरण थपिएको छैन' : 'No steps added yet',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                )
              else
                ..._steps.map((st) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: SitiColors.terracotta.withValues(alpha: 0.15),
                        child: Text('${st.order}', style: TextStyle(fontSize: 11, color: SitiColors.terracotta)),
                      ),
                      title: Text(st.instructionNe),
                      trailing: st.isWhistleStep ? Icon(Icons.volume_up, size: 18, color: SitiColors.terracotta) : null,
                    )),

              const SizedBox(height: 8),
              // Add step input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('step_instruction_input'),
                      controller: _stepInstructionNeController,
                      decoration: InputDecoration(
                        hintText: _isNepali ? 'चरणको निर्देशन' : 'Step instruction',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('add_step_btn'),
                    icon: Icon(Icons.add_circle, color: SitiColors.terracotta),
                    onPressed: _addStep,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Cultural Story
              TextFormField(
                key: const Key('cultural_story_input'),
                controller: _culturalStoryController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _isNepali ? 'सांस्कृतिक कथा वा पारिवारिक इतिहास' : 'Cultural Story / History',
                  hintText: 'उदा: यो रेसिपी हाम्रो बज्यैले दशैंमा बनाउने चलन थियो...',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                key: const Key('submit_recipe_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SitiColors.terracotta,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isNepali ? 'रेसिपी पेश गर्नुहोस् (Submit)' : 'Submit Recipe',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionResultBanner(CommunityContribution contribution) {
    final mod = contribution.moderation;
    final isSafe = mod.isSafe;

    final color = isSafe ? Colors.green : Colors.red;

    return Container(
      key: const Key('submission_result_banner'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isSafe ? Icons.check_circle : Icons.error, color: color.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSafe
                      ? (_isNepali ? 'रेसिपी सफलतापूर्वक प्रकाशित भयो!' : 'Recipe Published!')
                      : (_isNepali ? 'समीक्षा आवश्यक' : 'Review Required'),
                  style: TextStyle(fontWeight: FontWeight.bold, color: color.shade900, fontSize: 14),
                ),
              ),
              CommunityBadge(badge: contribution.badge, isNepali: _isNepali),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isNepali ? mod.feedbackNe : mod.feedbackEn,
            style: TextStyle(fontSize: 12, color: color.shade900),
          ),
        ],
      ),
    );
  }
}
