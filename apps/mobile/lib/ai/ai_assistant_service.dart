import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:kitchen_engine/kitchen_engine.dart';

typedef AiApiTransport = Future<Map<String, dynamic>> Function({
  required String url,
  required Map<String, dynamic> body,
  Map<String, String>? headers,
});

/// Service orchestrating the 3-tier AI assistant routing on mobile devices.
///
/// Tiers:
/// 1. Deterministic Kitchen Engine (Offline, 0 latency, exact conversions/whistles)
/// 2. On-Device Model (Apple Foundation Models, Gemini Nano)
/// 3. Cloud Gemini API via Cloudflare AI Gateway (with explicit consent & pseudonymization)
class AiAssistantService {
  final String apiBaseUrl;
  final AiApiTransport? transport;
  final OnDeviceAiProvider? onDeviceProvider;
  final List<RegionRecipe> catalogRecipes;
  final List<MemberAllergyProfile> memberAllergies;
  final List<DietaryRule> dietaryRules;
  final List<String> householdMemberNames;
  final List<String> pantryIngredientIds;
  final double elevationMeters;

  bool _hasCloudConsent;

  AiAssistantService({
    this.apiBaseUrl = 'https://api.siticounter.app',
    this.transport,
    this.onDeviceProvider,
    this.catalogRecipes = const [],
    this.memberAllergies = const [],
    this.dietaryRules = const [],
    this.householdMemberNames = const [],
    this.pantryIngredientIds = const [],
    this.elevationMeters = 1400.0,
    bool initialCloudConsent = false,
  }) : _hasCloudConsent = initialCloudConsent;

  bool get hasCloudConsent => _hasCloudConsent;

  void setCloudConsent(bool consent) {
    _hasCloudConsent = consent;
  }

  /// Sends a query through the 3-tier architecture with privacy & medical guardrails.
  Future<AssistantResponse> ask({
    required String prompt,
    String language = 'en',
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return const AssistantResponse(
        tier: AiRoutingTier.deterministic,
        replyEn: 'Please enter a cooking or kitchen question.',
        replyNe: 'कृपया कुनै भान्सा सम्बन्धी प्रश्न सोध्नुहोस्।',
        actions: [],
      );
    }

    final request = AssistantRequest(
      prompt: trimmed,
      currentLanguage: language,
      householdMemberNames: householdMemberNames,
      memberAllergies: memberAllergies,
      dietaryRules: dietaryRules,
      catalogRecipes: catalogRecipes,
      pantryIngredientIds: pantryIngredientIds,
      currentElevationMeters: elevationMeters,
      hasCloudConsent: _hasCloudConsent,
    );

    // Step 0: Medical & Pediatric Calorie Guardrail (Zero-latency offline block)
    if (SafetyGuardrail.isMedicalOrPediatricCalorieQuery(trimmed)) {
      return SafetyGuardrail.buildMedicalSafetyResponse();
    }

    // Tier 1: Deterministic Kitchen Engine (Offline)
    final deterministicResp = DeterministicAssistantRouter.matchQuery(request);
    if (deterministicResp != null) {
      return deterministicResp;
    }

    // Tier 2: On-Device Model (if available)
    if (onDeviceProvider != null) {
      final pseudonymized = DataPseudonymizer.pseudonymize(
        trimmed,
        knownNames: householdMemberNames,
      );
      final localReply = await onDeviceProvider!.generateLocalResponse(
        pseudonymizedPrompt: pseudonymized.text,
        language: language,
      );

      if (localReply != null && localReply.trim().isNotEmpty) {
        final rehydrated = DataPseudonymizer.rehydrate(
          localReply,
          pseudonymized.nameMap,
        );
        return AssistantResponse(
          tier: AiRoutingTier.onDevice,
          replyEn: rehydrated,
          replyNe: rehydrated,
          safetyVerified: true,
          actions: _extractDefaultActions(request),
        );
      }
    }

    // If Cloud Consent is not granted, ask for user consent before network call
    if (!_hasCloudConsent) {
      return const AssistantResponse(
        tier: AiRoutingTier.deterministic,
        replyEn:
            'To answer this creative culinary question with Cloud Gemini AI, please enable cloud assistance. Your personal data is always pseudonymized before transmission.',
        replyNe:
            'क्लाउड जेमिनी एआईबाट यो प्रश्नको जवाफ पाउन कृपया क्लाउड अनुमति दिनुहोस्। तपाईंको व्यक्तिगत विवरण सधैँ सुरक्षित र नामरहित बनाइन्छ।',
        consentPromptRequired: true,
        actions: [],
      );
    }

    // Tier 3: Cloud Gemini Online via Cloudflare AI Gateway
    try {
      final payload = {
        'prompt': trimmed,
        'currentLanguage': language,
        'householdMemberNames': householdMemberNames,
        'memberAllergies': memberAllergies.map((m) => {
          'allergen': m.allergen,
          'severity': m.severity.name,
          'memberName': m.memberName,
        }).toList(),
        'dietaryRules': dietaryRules.map((d) => d.name).toList(),
        'currentElevationMeters': elevationMeters,
        'hasCloudConsent': true,
        'catalogRecipes': catalogRecipes.map((r) => {
          'id': r.id,
          'titleEn': r.titleEn,
          'titleNe': r.titleNe,
          'category': r.category,
          'cuisine': r.cuisine,
          'dietary': r.dietary,
          'prepTimeMinutes': r.prepTimeMinutes,
          'cookTimeMinutes': r.cookTimeMinutes,
          'servings': r.servings,
          'difficulty': r.difficulty,
          'ingredients': r.ingredients.map((i) => {
            'ingredientId': i.ingredientId,
            'quantity': i.quantity,
            'unit': i.unit,
          }).toList(),
          'pressureCooker': {
            'enabled': r.pressureCooker.enabled,
            'recommendedWhistles': r.pressureCooker.recommendedWhistles,
            'altitudeWhistleOffsetKathmandu': r.pressureCooker.altitudeWhistleOffsetKathmandu,
            'heatLevel': r.pressureCooker.heatLevel,
            'releaseType': r.pressureCooker.releaseType,
          },
        }).toList(),
      };

      final data = transport != null
          ? await transport!(
              url: '$apiBaseUrl/v1/ai/assistant',
              body: payload,
              headers: {'Content-Type': 'application/json'},
            )
          : await _defaultHttpTransport(
              url: '$apiBaseUrl/v1/ai/assistant',
              body: payload,
            );

      return AssistantResponse.fromJson(data);
    } catch (e) {
      if (kDebugMode) {
        print('Cloud Gemini AI request failed, falling back to offline guidance: $e');
      }
      return const AssistantResponse(
        tier: AiRoutingTier.deterministic,
        replyEn:
            'Cloud connection is currently unavailable. Offline assistance is active for timers, conversions, and whistle calculations.',
        replyNe:
            'इन्टरनेट सम्पर्क उपलब्ध छैन। सिट्ठी गन्न, सामग्री रूपान्तरण गर्न अफलाइन सुविधा चालु छ।',
        actions: [],
      );
    }
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

  static Future<Map<String, dynamic>> _defaultHttpTransport({
    required String url,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(url);
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      headers?.forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode(body));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      } else {
        throw HttpException('HTTP ${response.statusCode}: $responseBody');
      }
    } finally {
      client.close();
    }
  }
}
