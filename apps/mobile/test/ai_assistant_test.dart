import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/ai/ai_assistant_screen.dart';
import 'package:siti_counter/ai/ai_assistant_service.dart';

class MockOnDeviceProvider implements OnDeviceAiProvider {
  final String? reply;
  MockOnDeviceProvider({this.reply});

  @override
  Future<String?> generateLocalResponse({
    required String pseudonymizedPrompt,
    required String language,
  }) async {
    return reply ?? 'Local advice: Cook gently with love for [FamilyMember_1].';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dalRecipe = RegionRecipe(
    id: 'masyaura_dal',
    titleEn: 'Masyaura Dal',
    titleNe: 'मस्यौरा दाल',
    category: 'Lentils & Pulses',
    cuisine: 'Nepali',
    dietary: const ['Vegetarian'],
    prepTimeMinutes: 15,
    cookTimeMinutes: 25,
    servings: 4,
    difficulty: 'Easy',
    ingredients: const [
      RecipeIngredientItem(ingredientId: 'musuro_dal', quantity: 200, unit: 'g'),
      RecipeIngredientItem(ingredientId: 'onion', quantity: 100, unit: 'g'),
    ],
    pressureCooker: const RecipeWhistleProfile(
      enabled: true,
      recommendedWhistles: 3,
      altitudeWhistleOffsetKathmandu: 0,
      heatLevel: 'medium',
      releaseType: 'natural',
    ),
    seasonality: const ['all_year'],
    tags: const ['dal', 'lentils'],
  );

  group('AiAssistantService Unit Tests', () {
    test('answers unit conversions deterministically (Tier 1 offline)', () async {
      final service = AiAssistantService(
        catalogRecipes: [dalRecipe],
      );

      final resp = await service.ask(prompt: 'How many grams in 2 pau?');
      expect(resp.tier, equals(AiRoutingTier.deterministic));
      expect(resp.replyEn, contains('500 grams'));
      expect(resp.consentPromptRequired, isFalse);
    });

    test('blocks pediatric calorie and medical advice with gentle disclaimer', () async {
      final service = AiAssistantService();

      final resp = await service.ask(prompt: 'What is the daily calorie limit for my baby?');
      expect(resp.tier, equals(AiRoutingTier.deterministic));
      expect(resp.replyEn, contains('pediatrician'));
      expect(resp.actions, isEmpty);
    });

    test('routes through on-device model when available (Tier 2)', () async {
      final service = AiAssistantService(
        onDeviceProvider: MockOnDeviceProvider(),
        householdMemberNames: ['Bikram'],
      );

      final resp = await service.ask(prompt: 'Any quick tip for Bikram dinner?');
      expect(resp.tier, equals(AiRoutingTier.onDevice));
      // Synthetic token [FamilyMember_1] should be rehydrated back to Bikram
      expect(resp.replyEn, contains('Bikram'));
    });

    test('requires cloud consent when query falls through to Tier 3', () async {
      final service = AiAssistantService(
        initialCloudConsent: false,
      );

      final resp = await service.ask(prompt: 'Suggest a creative fusion dinner with story');
      expect(resp.consentPromptRequired, isTrue);
      expect(resp.replyEn, contains('enable cloud assistance'));
    });

    test('invokes cloud transport when cloud consent is enabled', () async {
      var transportInvoked = false;
      final service = AiAssistantService(
        initialCloudConsent: true,
        transport: ({required body, required url, headers}) async {
          transportInvoked = true;
          return {
            'tier': 'cloudGemini',
            'replyEn': 'Here is an exquisite festive Dal Bhat recipe.',
            'replyNe': 'यहाँ उत्कृष्ट चाडपर्वको दाल भात परिकार छ।',
            'actions': [
              {
                'type': 'cookNow',
                'labelEn': 'Cook Masyaura Dal',
                'labelNe': 'मस्यौरा दाल पकाउनुहोस्',
                'recipeId': 'masyaura_dal',
                'recipeTitleEn': 'Masyaura Dal',
                'whistles': 3,
              }
            ],
            'safetyVerified': true,
          };
        },
      );

      final resp = await service.ask(prompt: 'Suggest a creative festival dinner');
      expect(transportInvoked, isTrue);
      expect(resp.tier, equals(AiRoutingTier.cloudGemini));
      expect(resp.replyEn, contains('festive Dal Bhat'));
      expect(resp.actions.length, equals(1));
      expect(resp.actions.first.type, equals(ActionType.cookNow));
    });
  });

  group('AiAssistantScreen Widget Tests', () {
    testWidgets('renders initial greeting and tier badge', (tester) async {
      final service = AiAssistantService();

      await tester.pumpWidget(
        MaterialApp(
          home: AiAssistantScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Siti AI Assistant'), findsOneWidget);
      expect(find.textContaining('Namaste!'), findsOneWidget);
      expect(find.text('Offline Engine (Tier 1)'), findsOneWidget);
    });

    testWidgets('submits conversion query and displays Tier 1 answer', (tester) async {
      final service = AiAssistantService();

      await tester.pumpWidget(
        MaterialApp(
          home: AiAssistantScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();

      // Enter query
      await tester.enterText(
        find.byKey(const Key('ai_assistant_input_field')),
        'How many grams in 2 pau?',
      );
      await tester.tap(find.byKey(const Key('ai_assistant_send_button')));
      await tester.pumpAndSettle();

      expect(find.text('How many grams in 2 pau?'), findsNWidgets(2));
      expect(find.textContaining('500 grams'), findsOneWidget);
    });

    testWidgets('submits medical query and shows safety disclaimer with shield icon', (tester) async {
      final service = AiAssistantService();

      await tester.pumpWidget(
        MaterialApp(
          home: AiAssistantScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ai_assistant_input_field')),
        'What is the daily calorie limit for my baby?',
      );
      await tester.tap(find.byKey(const Key('ai_assistant_send_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('pediatrician'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('shows consent card and enables cloud consent on button tap', (tester) async {
      final service = AiAssistantService(initialCloudConsent: false);

      await tester.pumpWidget(
        MaterialApp(
          home: AiAssistantScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ai_assistant_input_field')),
        'Tell me a creative story about Gundruk',
      );
      await tester.tap(find.byKey(const Key('ai_assistant_send_button')));
      await tester.pumpAndSettle();

      expect(find.text('Cloud AI Consent'), findsOneWidget);
      expect(find.byKey(const Key('enable_cloud_consent_button')), findsOneWidget);

      // Tap enable consent button
      await tester.tap(find.byKey(const Key('enable_cloud_consent_button')));
      await tester.pumpAndSettle();

      expect(service.hasCloudConsent, isTrue);
    });

    testWidgets('renders executable action buttons and handles tap', (tester) async {
      var cookNowOpened = false;
      final service = AiAssistantService(
        initialCloudConsent: true,
        transport: ({required body, required url, headers}) async {
          return {
            'tier': 'deterministic',
            'replyEn': 'You can prepare delicious Masyaura Dal today.',
            'replyNe': 'तपाईं स्वादिष्ट मस्यौरा दाल बनाउन सक्नुहुन्छ।',
            'actions': [
              {
                'type': 'cookNow',
                'labelEn': 'Cook Masyaura Dal',
                'labelNe': 'मस्यौरा दाल पकाउनुहोस्',
                'recipeId': 'masyaura_dal',
                'recipeTitleEn': 'Masyaura Dal',
                'whistles': 3,
              },
              {
                'type': 'addToPlan',
                'labelEn': 'Add to Plan',
                'labelNe': 'तालिकामा थप्नुहोस्',
                'recipeId': 'masyaura_dal',
              },
            ],
            'safetyVerified': true,
          };
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AiAssistantScreen(
            service: service,
            onOpenCookNow: () {
              cookNowOpened = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ai_assistant_input_field')),
        'What should I cook?',
      );
      await tester.tap(find.byKey(const Key('ai_assistant_send_button')));
      await tester.pumpAndSettle();

      expect(find.text('Cook Masyaura Dal'), findsOneWidget);
      expect(find.text('Add to Plan'), findsOneWidget);

      // Tap Cook Now action button
      await tester.tap(find.text('Cook Masyaura Dal'));
      await tester.pumpAndSettle();

      expect(cookNowOpened, isTrue);
      expect(find.textContaining('Starting cooking session'), findsOneWidget);
    });
  });
}
