import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:siti_counter/community/community_badge.dart';
import 'package:siti_counter/community/community_recipe_form_screen.dart';
import 'package:siti_counter/community/community_service.dart';
import 'package:siti_counter/community/ingredient_alias_sheet.dart';
import 'package:siti_counter/community/market_price_report_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommunityBadge Widget Tests', () {
    testWidgets('renders Verified badge in Nepali and English', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CommunityBadge(badge: VerificationBadge.verified, isNepali: true),
                CommunityBadge(badge: VerificationBadge.verified, isNepali: false),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('badge_verified')), findsNWidgets(2));
      expect(find.text('प्रमाणित (Verified)'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsNWidgets(2));
    });

    testWidgets('renders Community badge in Nepali and English', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CommunityBadge(badge: VerificationBadge.community, isNepali: true),
                CommunityBadge(badge: VerificationBadge.community, isNepali: false),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('badge_community')), findsNWidgets(2));
      expect(find.text('सामुदायिक (Community)'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.byIcon(Icons.groups_outlined), findsNWidgets(2));
    });
  });

  group('CommunityRecipeFormScreen Widget Tests', () {
    testWidgets('fills and submits authentic recipe with instant community badge',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = CommunityService();

      await tester.pumpWidget(
        MaterialApp(
          home: CommunityRecipeFormScreen(
            service: service,
            currentLanguage: 'ne',
          ),
        ),
      );

      // Enter recipe title
      await tester.enterText(
          find.byKey(const Key('recipe_title_ne_input')), 'गुन्द्रुकको झोल');
      await tester.enterText(
          find.byKey(const Key('recipe_title_en_input')), 'Gundruk Soup');

      // Add ingredient
      await tester.enterText(find.byKey(const Key('ing_name_input')), 'गुन्द्रुक');
      await tester.tap(find.byKey(const Key('add_ingredient_btn')));
      await tester.pumpAndSettle();

      expect(find.text('गुन्द्रुक (गुन्द्रुक)'), findsOneWidget);

      // Add step
      await tester.enterText(find.byKey(const Key('step_instruction_input')),
          'तोरीको तेलमा मेथी पड्काएर गुन्द्रुक भुट्नुहोस्।');
      await tester.tap(find.byKey(const Key('add_step_btn')));
      await tester.pumpAndSettle();

      expect(find.text('तोरीको तेलमा मेथी पड्काएर गुन्द्रुक भुट्नुहोस्।'), findsOneWidget);

      // Cultural story
      await tester.enterText(
          find.byKey(const Key('cultural_story_input')),
          'हाम्रो पहाडी भेगमा जाडो महिनामा मकैको च्याँख्लासँग खाने मुख्य परिकार।');

      // Tap submit
      final submitBtn = find.byKey(const Key('submit_recipe_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify submission banner & badge
      expect(find.byKey(const Key('submission_result_banner')), findsOneWidget);
      expect(find.text('रेसिपी सफलतापूर्वक प्रकाशित भयो!'), findsOneWidget);
      expect(find.byKey(const Key('badge_community')), findsOneWidget);
      expect(service.contributions.length, 1);
      expect(service.contributions.first.status, ContributionStatus.autoApproved);
    });
  });

  group('IngredientAliasSheet & MarketPriceReportSheet Widget Tests', () {
    testWidgets('IngredientAliasSheet proposes dialect name and renders community badge',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = CommunityService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_alias_btn'),
                onPressed: () => IngredientAliasSheet.show(
                  context: ctx,
                  service: service,
                  canonicalIngredientId: 'cauliflower',
                  ingredientNameNe: 'काउली',
                  ingredientNameEn: 'Cauliflower',
                  currentLanguage: 'ne',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_alias_btn')));
      await tester.pumpAndSettle();

      expect(find.text('काउली (Cauliflower)'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('alias_name_ne_input')), 'गोभी');
      await tester.enterText(
          find.byKey(const Key('alias_name_en_input')), 'Gobhi');

      final submitBtn = find.byKey(const Key('submit_alias_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(service.contributions.length, 1);
      expect(service.contributions.first.type, ContributionType.ingredientAlias);
      expect(find.text('सामग्रीको स्थानीय नाम स्वीकार गरियो।'), findsOneWidget);
      expect(find.byKey(const Key('badge_community')), findsOneWidget);
    });

    testWidgets('MarketPriceReportSheet submits observation and flags outliers',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = CommunityService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_price_btn'),
                onPressed: () => MarketPriceReportSheet.show(
                  context: ctx,
                  service: service,
                  commodityId: 'potato',
                  commodityNameNe: 'आलु रातो',
                  commodityNameEn: 'Potato Red',
                  baselineAvgPrice: 60,
                  currentLanguage: 'ne',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_price_btn')));
      await tester.pumpAndSettle();

      // Normal price: 65 NPR
      await tester.enterText(find.byKey(const Key('observed_price_input')), '65');
      final submitBtn = find.byKey(const Key('submit_price_report_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(service.contributions.length, 1);
      expect(service.contributions.first.status, ContributionStatus.autoApproved);
      expect(find.text('बजार मूल्य रिपोर्ट स्वीकृत भयो।'), findsOneWidget);

      // Human review promotion to "verified"
      final contribution = service.contributions.first;
      final reviewed = await service.reviewContribution(
        contributionId: contribution.id,
        reviewerId: 'editor_market_curator',
        decision: 'promote_to_verified',
        notes: 'Price matches local wet market vendor receipts.',
      );

      expect(reviewed, isNotNull);
      expect(reviewed!.badge, VerificationBadge.verified);
      expect(reviewed.status, ContributionStatus.verified);
    });
  });
}
