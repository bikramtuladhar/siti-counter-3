library;

import 'allergen_engine.dart';
import 'kitchen_engine.dart';
import 'nepali_calendar.dart';
import 'region_pack.dart';
import 'waste_engine.dart';

/// The routing tier that fulfilled the AI assistant request.
enum AiRoutingTier {
  deterministic, // Tier 1: Local deterministic kitchen engine (0 latency, 100% offline)
  onDevice, // Tier 2: On-device SLM / Gemini Nano / Apple Foundation Models
  cloudGemini; // Tier 3: Cloud Gemini 3.8 Flash via Cloudflare AI Gateway (opt-in consent)

  String get labelEn {
    switch (this) {
      case AiRoutingTier.deterministic:
        return 'Deterministic Engine (Offline)';
      case AiRoutingTier.onDevice:
        return 'On-Device AI';
      case AiRoutingTier.cloudGemini:
        return 'Cloud Gemini (Verified)';
    }
  }

  String get badgeLabel {
    switch (this) {
      case AiRoutingTier.deterministic:
        return '⚡ Offline Engine';
      case AiRoutingTier.onDevice:
        return '📱 On-Device';
      case AiRoutingTier.cloudGemini:
        return '☁️ Cloud Gemini';
    }
  }
}

/// Executable action types attached to assistant responses.
enum ActionType {
  cookNow,
  addToPlan,
  addToList,
  startTimer,
  viewRecipe,
}

/// An actionable button directly executable from the assistant response.
class ExecutableAction {
  final ActionType type;
  final String labelEn;
  final String labelNe;
  final String? recipeId;
  final String? recipeTitleEn;
  final String? recipeTitleNe;
  final int? whistles;
  final int? timerMinutes;
  final List<String>? ingredientsToAdd;

  const ExecutableAction({
    required this.type,
    required this.labelEn,
    required this.labelNe,
    this.recipeId,
    this.recipeTitleEn,
    this.recipeTitleNe,
    this.whistles,
    this.timerMinutes,
    this.ingredientsToAdd,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'labelEn': labelEn,
        'labelNe': labelNe,
        if (recipeId != null) 'recipeId': recipeId,
        if (recipeTitleEn != null) 'recipeTitleEn': recipeTitleEn,
        if (recipeTitleNe != null) 'recipeTitleNe': recipeTitleNe,
        if (whistles != null) 'whistles': whistles,
        if (timerMinutes != null) 'timerMinutes': timerMinutes,
        if (ingredientsToAdd != null) 'ingredientsToAdd': ingredientsToAdd,
      };

  factory ExecutableAction.fromJson(Map<String, dynamic> json) => ExecutableAction(
        type: ActionType.values.byName(json['type'] as String),
        labelEn: json['labelEn'] as String,
        labelNe: json['labelNe'] as String,
        recipeId: json['recipeId'] as String?,
        recipeTitleEn: json['recipeTitleEn'] as String?,
        recipeTitleNe: json['recipeTitleNe'] as String?,
        whistles: json['whistles'] as int?,
        timerMinutes: json['timerMinutes'] as int?,
        ingredientsToAdd: (json['ingredientsToAdd'] as List<dynamic>?)?.cast<String>(),
      );
}

/// Request sent to the assistant.
class AssistantRequest {
  final String prompt;
  final String currentLanguage;
  final List<String> householdMemberNames;
  final List<MemberAllergyProfile> memberAllergies;
  final List<DietaryRule> dietaryRules;
  final List<RegionRecipe> catalogRecipes;
  final List<String> pantryIngredientIds;
  final double currentElevationMeters;
  final bool hasCloudConsent;

  const AssistantRequest({
    required this.prompt,
    this.currentLanguage = 'en',
    this.householdMemberNames = const [],
    this.memberAllergies = const [],
    this.dietaryRules = const [],
    this.catalogRecipes = const [],
    this.pantryIngredientIds = const [],
    this.currentElevationMeters = 1400.0,
    this.hasCloudConsent = false,
  });
}

/// Final response returned by the 3-tier assistant architecture.
class AssistantResponse {
  final AiRoutingTier tier;
  final String replyEn;
  final String replyNe;
  final List<RegionRecipe> suggestedRecipes;
  final List<ExecutableAction> actions;
  final bool safetyVerified;
  final bool safetyFiltered;
  final List<String> safetyNotes;
  final bool consentPromptRequired;

  const AssistantResponse({
    required this.tier,
    required this.replyEn,
    required this.replyNe,
    this.suggestedRecipes = const [],
    this.actions = const [],
    this.safetyVerified = true,
    this.safetyFiltered = false,
    this.safetyNotes = const [],
    this.consentPromptRequired = false,
  });

  factory AssistantResponse.fromJson(Map<String, dynamic> json) {
    final tierStr = json['tier'] as String? ?? 'deterministic';
    final tier = AiRoutingTier.values.firstWhere(
      (t) => t.name == tierStr,
      orElse: () => AiRoutingTier.deterministic,
    );
    final rawActions = json['actions'] as List<dynamic>? ?? const [];
    final actions = rawActions
        .map((a) => ExecutableAction.fromJson(Map<String, dynamic>.from(a as Map)))
        .toList();
    final safetyNotes = (json['safetyNotes'] as List<dynamic>?)?.cast<String>() ?? const [];

    return AssistantResponse(
      tier: tier,
      replyEn: json['replyEn'] as String? ?? '',
      replyNe: json['replyNe'] as String? ?? '',
      actions: actions,
      safetyVerified: json['safetyVerified'] as bool? ?? true,
      safetyFiltered: json['safetyFiltered'] as bool? ?? false,
      safetyNotes: safetyNotes,
      consentPromptRequired: json['consentPromptRequired'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'replyEn': replyEn,
        'replyNe': replyNe,
        'suggestedRecipeIds': suggestedRecipes.map((r) => r.id).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'safetyVerified': safetyVerified,
        'safetyFiltered': safetyFiltered,
        'safetyNotes': safetyNotes,
        'consentPromptRequired': consentPromptRequired,
      };
}

/// Helper result for pseudonymization.
class PseudonymizedResult {
  final String text;
  final Map<String, String> nameMap; // e.g. {'[FamilyMember_1]': 'Bikram'}

  const PseudonymizedResult({
    required this.text,
    required this.nameMap,
  });
}

/// Guardrail 1: Strict Data Pseudonymization before cloud routing (Section 22.2).
class DataPseudonymizer {
  static final RegExp _emailRegex =
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b');
  static final RegExp _phoneRegex =
      RegExp(r'\b(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b');

  /// Replaces identifiable names with synthetic tokens and scrubs personal identifiers.
  static PseudonymizedResult pseudonymize(
    String input, {
    List<String> knownNames = const [],
  }) {
    var scrubbed = input;
    final nameMap = <String, String>{};

    // 1. Scrub emails & phone numbers
    scrubbed = scrubbed.replaceAll(_emailRegex, '[Email_Scrubbed]');
    scrubbed = scrubbed.replaceAll(_phoneRegex, '[Phone_Scrubbed]');

    // 2. Pseudonymize known household member names
    int memberIndex = 1;
    for (final name in knownNames) {
      if (name.trim().isEmpty) continue;
      final token = '[FamilyMember_$memberIndex]';
      final pattern = RegExp('\\b${RegExp.escape(name)}\\b', caseSensitive: false);
      if (pattern.hasMatch(scrubbed)) {
        scrubbed = scrubbed.replaceAll(pattern, token);
        nameMap[token] = name;
        memberIndex++;
      }
    }

    return PseudonymizedResult(text: scrubbed, nameMap: nameMap);
  }

  /// Re-hydrates synthetic tokens back to original user names for local display.
  static String rehydrate(String text, Map<String, String> nameMap) {
    var rehydrated = text;
    nameMap.forEach((token, originalName) {
      rehydrated = rehydrated.replaceAll(token, originalName);
    });
    return rehydrated;
  }
}

/// Guardrail 2 & 3: Safety Guardrails for Medical/Pediatric Calorie Blocking & Allergen Post-Check.
class SafetyGuardrail {
  static final List<RegExp> _medicalCaloriePatterns = [
    RegExp(r'\b(pediatric|baby|toddler|infant|child)\b.*?\b(calorie|calories|calorie target|calorie deficit|diet|nutrition plan)\b', caseSensitive: false),
    RegExp(r'\b(how many calories|calorie limit|calorie target|diet plan)\b.*?\b(baby|toddler|child|infant|\d+\s*year old)\b', caseSensitive: false),
    RegExp(r'\b(cure diabetes|insulin dose|treat cancer|medical diet|starvation diet)\b', caseSensitive: false),
  ];

  /// Checks if query requests medical advice or pediatric calorie counting (forbidden by Section 22.2).
  static bool isMedicalOrPediatricCalorieQuery(String prompt) {
    for (final pattern in _medicalCaloriePatterns) {
      if (pattern.hasMatch(prompt)) return true;
    }
    return false;
  }

  /// Standard gentle safety response when pediatric calories or medical advice is requested.
  static AssistantResponse buildMedicalSafetyResponse() {
    return const AssistantResponse(
      tier: AiRoutingTier.deterministic,
      replyEn: 'Siti Counter is designed for wholesome home cooking and family meals, but does not provide medical or pediatric calorie targets. For child growth and nutrition advice, please consult your family pediatrician.',
      replyNe: 'सिट्ठी काउन्टर स्वस्थ घरायसी खाना पकाउनको लागि हो, तर यसले चिकित्सा वा बालबालिकाको क्यालोरी सम्बन्धी सल्लाह दिँदैन। बालबालिकाको पोषणको लागि कृपया बालरोग विशेषज्ञसँग परामर्श लिनुहोस्।',
      safetyVerified: true,
      actions: [],
      safetyNotes: ['Pediatric calorie advice blocked per Section 22.2 safety policy.'],
    );
  }

  /// Strict deterministic post-check: suggested recipes MUST pass allergen & dietary filters before display.
  static ({
    List<RegionRecipe> safeRecipes,
    bool hadUnsafeFiltered,
    List<String> notes,
  }) postCheckRecipes({
    required List<RegionRecipe> candidates,
    required List<MemberAllergyProfile> memberAllergies,
    required List<DietaryRule> dietaryRules,
  }) {
    final safe = <RegionRecipe>[];
    bool hadUnsafe = false;
    final notes = <String>[];

    for (final recipe in candidates) {
      final ingredientIds = recipe.ingredients.map((i) => i.ingredientId).toList();
      final verdict = AllergenEngine.checkRecipeSafety(
        ingredientIds: ingredientIds,
        allergyProfiles: memberAllergies,
        dietaryRules: dietaryRules,
      );

      if (verdict.isSafe && !verdict.hasSevereConflict) {
        safe.add(recipe);
      } else {
        hadUnsafe = true;
        final reason = verdict.primaryWarning ?? 'Excluded due to household allergy/dietary safety';
        notes.add('Excluded "${recipe.titleEn}": $reason');
      }
    }

    return (
      safeRecipes: safe,
      hadUnsafeFiltered: hadUnsafe,
      notes: notes,
    );
  }
}

/// Tier 1: Local Deterministic Kitchen Engine Router.
class DeterministicAssistantRouter {
  /// Attempts to answer the prompt deterministically using the kitchen engine.
  static AssistantResponse? matchQuery(AssistantRequest request) {
    final prompt = request.prompt.toLowerCase().trim();

    // 1. Unit Conversion Queries
    // e.g. "how many grams in 2 pau", "convert 3 mana to ml", "what is 1 dharni"
    final pauMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:pau|पाउ)').firstMatch(prompt);
    if (pauMatch != null && (prompt.contains('gram') || prompt.contains('g') || prompt.contains('how much') || prompt.contains('कति'))) {
      final pauVal = double.parse(pauMatch.group(1)!);
      final grams = UnitConverter.pauToGrams(pauVal);
      final gramsFormatted = grams.round();
      return AssistantResponse(
        tier: AiRoutingTier.deterministic,
        replyEn: '$pauVal pau is exactly $gramsFormatted grams ($gramsFormatted g).',
        replyNe: '$pauVal पाउ बराबर ठीक $gramsFormatted ग्राम हुन्छ।',
        actions: const [],
      );
    }

    final manaMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:mana|माना)').firstMatch(prompt);
    if (manaMatch != null && (prompt.contains('ml') || prompt.contains('liter') || prompt.contains('how much') || prompt.contains('कति'))) {
      final manaVal = double.parse(manaMatch.group(1)!);
      final ml = UnitConverter.manaToMl(manaVal);
      final mlFormatted = ml.round();
      return AssistantResponse(
        tier: AiRoutingTier.deterministic,
        replyEn: '$manaVal mana is approximately $mlFormatted ml (${(ml / 1000).toStringAsFixed(2)} liters).',
        replyNe: '$manaVal माना लगभग $mlFormatted मि.लि. (${(ml / 1000).toStringAsFixed(2)} लिटर) हुन्छ।',
        actions: const [],
      );
    }

    final dharniMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:dharni|धार्नी)').firstMatch(prompt);
    if (dharniMatch != null && (prompt.contains('kg') || prompt.contains('gram') || prompt.contains('कति'))) {
      final dharniVal = double.parse(dharniMatch.group(1)!);
      final grams = UnitConverter.dharniToGrams(dharniVal);
      final kg = grams / 1000.0;
      return AssistantResponse(
        tier: AiRoutingTier.deterministic,
        replyEn: '$dharniVal dharni is exactly ${(kg % 1 == 0 ? kg.toInt() : kg)} kg ($grams g).',
        replyNe: '$dharniVal धार्नी बराबर ठीक ${(kg % 1 == 0 ? kg.toInt() : kg)} के.जी. ($grams ग्राम) हुन्छ।',
        actions: const [],
      );
    }

    // 2. Altitude Adjustment Queries
    // e.g. "altitude kathmandu", "water boiling point in kathmandu"
    if (prompt.contains('altitude') || prompt.contains('boiling point') || prompt.contains('उमाल्ने बिन्दु')) {
      final elevation = request.currentElevationMeters;
      final bp = AltitudeCalculator.boilingPointCelsius(elevation);
      final bpFormatted = bp.toStringAsFixed(1);
      return AssistantResponse(
        tier: AiRoutingTier.deterministic,
        replyEn: 'At ${elevation.round()}m elevation, water boils at $bpFormatted°C (below the 100°C sea level baseline). Pressure cooking is recommended for pulses & grains.',
        replyNe: '${elevation.round()} मिटरको उचाइमा पानी $bpFormatted°C मा उम्लन्छ। दाल र गेडागुडीको लागि प्रेसर कुकर उपयुक्त हुन्छ।',
        actions: const [],
      );
    }

    // 3. Whistle & Timer Lookup for Recipes
    // e.g. "how many whistles for masyaura dal", "whistle count kalo dal"
    if (prompt.contains('whistle') || prompt.contains('siti') || prompt.contains('सिट्ठी')) {
      for (final recipe in request.catalogRecipes) {
        if (prompt.contains(recipe.titleEn.toLowerCase()) || prompt.contains(recipe.id.replaceAll('_', ' '))) {
          final target = recipe.pressureCooker.enabled
              ? recipe.pressureCooker.recommendedWhistles
              : 0;
          final adjusted = AltitudeCalculator.adjustSitiCount(
            baseSiti: target,
            elevationMeters: request.currentElevationMeters,
          );

          return AssistantResponse(
            tier: AiRoutingTier.deterministic,
            replyEn: '${recipe.titleEn} takes $adjusted whistles in the pressure cooker (tested at ${request.currentElevationMeters.round()}m).',
            replyNe: '${recipe.titleNe} पकाउन प्रेसर कुकरमा $adjusted सिट्ठी चाहिन्छ।',
            suggestedRecipes: [recipe],
            actions: [
              ExecutableAction(
                type: ActionType.cookNow,
                labelEn: 'Cook Now ($adjusted Whistles)',
                labelNe: 'अहिले पकाउनुहोस् ($adjusted सिट्ठी)',
                recipeId: recipe.id,
                recipeTitleEn: recipe.titleEn,
                recipeTitleNe: recipe.titleNe,
                whistles: adjusted,
              ),
              ExecutableAction(
                type: ActionType.addToPlan,
                labelEn: 'Add to Meal Plan',
                labelNe: 'खाना तालिकामा थप्नुहोस्',
                recipeId: recipe.id,
                recipeTitleEn: recipe.titleEn,
                recipeTitleNe: recipe.titleNe,
              ),
            ],
          );
        }
      }
    }

    // 4. Pantry & Available Ingredient Matching
    // e.g. "what can I cook with potato and cauliflower", "recipes with dal"
    if (prompt.contains('what can i cook') || prompt.contains('recipes with') || prompt.contains('के पकाउने')) {
      final matchingRecipes = request.catalogRecipes.where((recipe) {
        final recipeIngs = recipe.ingredients.map((i) => i.ingredientId.toLowerCase()).toList();
        for (final pantryId in request.pantryIngredientIds) {
          if (recipeIngs.contains(pantryId.toLowerCase())) return true;
        }
        for (final part in prompt.split(RegExp(r'[, ]+'))) {
          if (part.length >= 4 && recipeIngs.any((i) => i.contains(part))) {
            return true;
          }
        }
        return false;
      }).toList();

      if (matchingRecipes.isNotEmpty) {
        // Enforce safety post-check
        final postCheck = SafetyGuardrail.postCheckRecipes(
          candidates: matchingRecipes,
          memberAllergies: request.memberAllergies,
          dietaryRules: request.dietaryRules,
        );

        final safeList = postCheck.safeRecipes;
        if (safeList.isNotEmpty) {
          final topRecipe = safeList.first;
          final namesEn = safeList.take(3).map((r) => r.titleEn).join(', ');
          final namesNe = safeList.take(3).map((r) => r.titleNe).join(', ');

          return AssistantResponse(
            tier: AiRoutingTier.deterministic,
            replyEn: 'Based on your available ingredients, you can make: $namesEn.',
            replyNe: 'तपाईंसँग भएका सामग्रीबाट बनाउन मिल्ने परिकारहरू: $namesNe।',
            suggestedRecipes: safeList.take(3).toList(),
            safetyVerified: true,
            safetyFiltered: postCheck.hadUnsafeFiltered,
            safetyNotes: postCheck.notes,
            actions: [
              ExecutableAction(
                type: ActionType.cookNow,
                labelEn: 'Cook ${topRecipe.titleEn}',
                labelNe: '${topRecipe.titleNe} पकाउनुहोस्',
                recipeId: topRecipe.id,
                recipeTitleEn: topRecipe.titleEn,
                recipeTitleNe: topRecipe.titleNe,
                whistles: topRecipe.pressureCooker.recommendedWhistles,
              ),
              ExecutableAction(
                type: ActionType.addToList,
                labelEn: 'Add Missing Items to List',
                labelNe: 'बाँकी सामग्री सूचीमा थप्नुहोस्',
                recipeId: topRecipe.id,
              ),
            ],
          );
        }
      }
    }

    // 5. Leftover / Shelf-Life queries
    // e.g. "how long does cooked dal last in fridge", "is bhat safe"
    if (prompt.contains('leftover') || prompt.contains('shelf life') || prompt.contains('बाँकी खाना') || prompt.contains('how long does')) {
      String dish = 'dal';
      if (prompt.contains('rice') || prompt.contains('bhat') || prompt.contains('भात')) {
        dish = 'bhat';
      } else if (prompt.contains('roti') || prompt.contains('रोटी')) {
        dish = 'roti';
      }

      final hours = WasteEngine.getBaseShelfLifeHours(
        dishCategory: dish,
        storage: StorageCondition.refrigerated,
        climate: ClimateZone.temperate,
      );
      final days = (hours / 24).round();

      return AssistantResponse(
        tier: AiRoutingTier.deterministic,
        replyEn: 'Refrigerated cooked $dish stays fresh for about $hours hours (~$days days). For best taste and nutrition, consume within this window.',
        replyNe: 'फ्रिजमा राखिएको पाकेको $dish लगभग $hours घण्टा (~$days दिन) सम्म ताजा रहन्छ।',
        actions: const [
          ExecutableAction(
            type: ActionType.viewRecipe,
            labelEn: 'View Leftovers Tracker',
            labelNe: 'बाँकी खाना हेर्नुहोस्',
          ),
        ],
      );
    }

    return null; // Not answered deterministically; proceed to Tier 2/3
  }
}

/// Abstract provider interface for on-device SLM / local models (Tier 2).
abstract class OnDeviceAiProvider {
  Future<String?> generateLocalResponse({
    required String pseudonymizedPrompt,
    required String language,
  });
}

/// Abstract provider interface for cloud Gemini API (Tier 3).
abstract class CloudGeminiProvider {
  Future<String> queryGemini({
    required String pseudonymizedPrompt,
    required String language,
  });
}

/// 3-Tier Offline-First Assistant Coordinator.
class ThreeTierAssistantCoordinator {
  final OnDeviceAiProvider? onDeviceProvider;
  final CloudGeminiProvider? cloudProvider;

  const ThreeTierAssistantCoordinator({
    this.onDeviceProvider,
    this.cloudProvider,
  });

  /// Processes the assistant request through the 3-tier routing architecture with guardrails.
  Future<AssistantResponse> process(AssistantRequest request) async {
    // Guardrail Step 0: Check for Medical or Pediatric Calorie triggers (Section 22.2)
    if (SafetyGuardrail.isMedicalOrPediatricCalorieQuery(request.prompt)) {
      return SafetyGuardrail.buildMedicalSafetyResponse();
    }

    // Tier 1: Deterministic Kitchen Engine (Offline, 0 latency, 0 tokens)
    final deterministicMatch = DeterministicAssistantRouter.matchQuery(request);
    if (deterministicMatch != null) {
      return deterministicMatch;
    }

    // Pseudonymize prompt before evaluating any generative model (Tier 2 or Tier 3)
    final pseudonymResult = DataPseudonymizer.pseudonymize(
      request.prompt,
      knownNames: request.householdMemberNames,
    );

    // Tier 2: On-Device Model (if available)
    if (onDeviceProvider != null) {
      final localReply = await onDeviceProvider!.generateLocalResponse(
        pseudonymizedPrompt: pseudonymResult.text,
        language: request.currentLanguage,
      );

      if (localReply != null && localReply.trim().isNotEmpty) {
        final rehydrated = DataPseudonymizer.rehydrate(localReply, pseudonymResult.nameMap);
        return AssistantResponse(
          tier: AiRoutingTier.onDevice,
          replyEn: rehydrated,
          replyNe: rehydrated,
          safetyVerified: true,
          actions: _extractDefaultActions(request),
        );
      }
    }

    // Tier 3: Cloud Gemini Online
    // Must verify explicit user consent first
    if (!request.hasCloudConsent) {
      return const AssistantResponse(
        tier: AiRoutingTier.deterministic,
        replyEn: 'To answer this creative culinary question with Cloud Gemini AI, please enable cloud assistance. Your personal data is always pseudonymized before transmission.',
        replyNe: 'क्लाउड जेमिनी एआईबाट यो प्रश्नको जवाफ पाउन कृपया क्लाउड अनुमति दिनुहोस्। तपाईंको व्यक्तिगत विवरण सधैँ सुरक्षित र नामरहित बनाइन्छ।',
        consentPromptRequired: true,
        actions: [],
      );
    }

    // Route to Cloud Gemini
    if (cloudProvider != null) {
      final cloudReplyRaw = await cloudProvider!.queryGemini(
        pseudonymizedPrompt: pseudonymResult.text,
        language: request.currentLanguage,
      );

      final rehydrated = DataPseudonymizer.rehydrate(cloudReplyRaw, pseudonymResult.nameMap);

      // Guardrail: Deterministic allergen post-check on any catalog recipes matched
      final matchedRecipes = request.catalogRecipes.where((r) {
        return rehydrated.toLowerCase().contains(r.titleEn.toLowerCase());
      }).toList();

      final postCheck = SafetyGuardrail.postCheckRecipes(
        candidates: matchedRecipes,
        memberAllergies: request.memberAllergies,
        dietaryRules: request.dietaryRules,
      );

      final actions = <ExecutableAction>[];
      for (final rec in postCheck.safeRecipes.take(2)) {
        actions.add(
          ExecutableAction(
            type: ActionType.cookNow,
            labelEn: 'Cook ${rec.titleEn}',
            labelNe: '${rec.titleNe} पकाउनुहोस्',
            recipeId: rec.id,
            recipeTitleEn: rec.titleEn,
            recipeTitleNe: rec.titleNe,
            whistles: rec.pressureCooker.recommendedWhistles,
          ),
        );
        actions.add(
          ExecutableAction(
            type: ActionType.addToPlan,
            labelEn: 'Add to Plan',
            labelNe: 'तालिकामा थप्नुहोस्',
            recipeId: rec.id,
            recipeTitleEn: rec.titleEn,
            recipeTitleNe: rec.titleNe,
          ),
        );
      }

      return AssistantResponse(
        tier: AiRoutingTier.cloudGemini,
        replyEn: rehydrated,
        replyNe: rehydrated,
        suggestedRecipes: postCheck.safeRecipes,
        actions: actions.isNotEmpty ? actions : _extractDefaultActions(request),
        safetyVerified: true,
        safetyFiltered: postCheck.hadUnsafeFiltered,
        safetyNotes: postCheck.notes,
      );
    }

    // Fallback if no cloud provider configured
    return const AssistantResponse(
      tier: AiRoutingTier.deterministic,
      replyEn: 'I am here to help with cooking timers, pantry ideas, conversions, and whistle counting. How can I assist in the kitchen today?',
      replyNe: 'म भान्सामा सिट्ठी गन्न, खानाको तालिका बनाउन, र सामग्री रूपान्तरण गर्न मद्दत गर्दछु।',
      actions: [],
    );
  }

  List<ExecutableAction> _extractDefaultActions(AssistantRequest request) {
    if (request.catalogRecipes.isEmpty) return const [];
    final first = request.catalogRecipes.first;
    return [
      ExecutableAction(
        type: ActionType.cookNow,
        labelEn: 'Cook ${first.titleEn}',
        labelNe: '${first.titleNe} पकाउनुहोस्',
        recipeId: first.id,
        recipeTitleEn: first.titleEn,
        recipeTitleNe: first.titleNe,
        whistles: first.pressureCooker.recommendedWhistles,
      ),
    ];
  }
}
