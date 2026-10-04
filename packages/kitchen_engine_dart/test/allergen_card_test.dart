import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('EmergencyAllergyCard Domain Tests', () {
    test('generates comprehensive bilingual allergy card with emergency contacts and EpiPen advice', () {
      const card = EmergencyAllergyCard(
        memberName: 'Aarav Sharma',
        memberAge: 6,
        severeAllergens: [
          AllergenCatalog.peanuts,
          AllergenCatalog.milk,
          AllergenCatalog.mustardOil,
        ],
        moderateAllergens: [
          AllergenCatalog.sesame,
        ],
        carriesEpiPen: true,
        emergencyContacts: [
          EmergencyContact(
            name: 'Pooja Sharma',
            relationship: 'Mother',
            phone: '+977-9801234567',
            secondaryPhone: '+977-9851000000',
          ),
          EmergencyContact(
            name: 'Bikram Sharma',
            relationship: 'Father',
            phone: '+977-9841234567',
          ),
        ],
        doctorName: 'Dr. Ramesh Thapa',
        doctorPhone: '+977-1-4412345',
      );

      // Verify allergen names in English and Devanagari
      expect(EmergencyAllergyCard.allergenNameEn(AllergenCatalog.peanuts), equals('Peanuts'));
      expect(EmergencyAllergyCard.allergenNameNe(AllergenCatalog.peanuts), contains('बदाम'));
      expect(EmergencyAllergyCard.allergenNameNe(AllergenCatalog.milk), contains('दूध'));
      expect(EmergencyAllergyCard.allergenNameNe(AllergenCatalog.mustardOil), contains('तोरीको तेल'));

      // Verify cross-contact warnings
      final hiddenEn = card.hiddenSourceWarningsEn;
      expect(hiddenEn.any((w) => w.contains('ghee') || w.contains('paneer')), isTrue);
      expect(hiddenEn.any((w) => w.contains('fenugreek') || w.contains('methi')), isTrue);

      final hiddenNe = card.hiddenSourceWarningsNe;
      expect(hiddenNe.any((w) => w.contains('घिउ') || w.contains('पनिर')), isTrue);

      // Verify markdown generation
      final markdown = card.generateMarkdownCard();
      expect(markdown, contains('Aarav Sharma'));
      expect(markdown, contains('ATTENTION CHEF'));
      expect(markdown, contains('शेफ / भान्से / वेटरको ध्यानाकर्षण'));
      expect(markdown, contains('EPINEPHRINE AUTO-INJECTOR'));
      expect(markdown, contains('+977-9801234567'));
      expect(markdown, contains('Dr. Ramesh Thapa'));
    });
  });

  group('InfantAllergenEngine Pediatric Introduction Tests', () {
    test('contains mandatory pediatric disclaimers and choking hazard warnings', () {
      expect(InfantAllergenEngine.pediatricDisclaimerEn, contains('PEDIATRIC DISCLAIMER'));
      expect(InfantAllergenEngine.pediatricDisclaimerNe, contains('बालरोग विशेषज्ञ'));

      final peanutChokingEn = InfantAllergenEngine.getChokingSafetyGuidanceEn(AllergenCatalog.peanuts);
      expect(peanutChokingEn, contains('Never feed whole nuts'));
      expect(peanutChokingEn, contains('Thin smooth peanut/nut butter'));

      final peanutChokingNe = InfantAllergenEngine.getChokingSafetyGuidanceNe(AllergenCatalog.peanuts);
      expect(peanutChokingNe, contains('सिंगो बदाम वा काजु कहिल्यै नदिनुहोस्'));
      expect(peanutChokingNe, contains('पातलो र नरम'));

      final eggChokingEn = InfantAllergenEngine.getChokingSafetyGuidanceEn(AllergenCatalog.eggs);
      expect(eggChokingEn, contains('thoroughly cooked'));

      final fishChokingEn = InfantAllergenEngine.getChokingSafetyGuidanceEn(AllergenCatalog.fish);
      expect(fishChokingEn, contains('remove all tiny bones'));
    });

    test('enforces spacing protocol and reaction safety gate', () {
      final now = DateTime(2026, 10, 4, 10, 0);

      // Log an adverse reaction to egg yesterday
      final logsWithAdverse = [
        InfantAllergenLog(
          id: 'log-1',
          memberId: 'baby-maya',
          allergen: AllergenCatalog.eggs,
          foodDescription: 'Mashed egg yolk',
          exposureDate: now.subtract(const Duration(days: 1)),
          portionGrams: 2.0,
          reactionSeverity: ReactionSeverity.mild,
          reactionSymptoms: 'Red hives around mouth',
        ),
      ];

      // Attempting to introduce peanut today should be rejected because of recent reaction
      final canIntroduce = InfantAllergenEngine.canIntroduceNewAllergen(
        recentLogs: logsWithAdverse,
        newAllergen: AllergenCatalog.peanuts,
        candidateDate: now,
      );
      expect(canIntroduce, isFalse);

      // Safe introduction after 4 days with no reaction
      final safeLogs = [
        InfantAllergenLog(
          id: 'log-2',
          memberId: 'baby-maya',
          allergen: AllergenCatalog.peanuts,
          foodDescription: 'Thinned peanut butter in puree',
          exposureDate: now.subtract(const Duration(days: 4)),
          portionGrams: 2.5,
          reactionSeverity: ReactionSeverity.none,
        ),
      ];

      final canIntroduceAfterWait = InfantAllergenEngine.canIntroduceNewAllergen(
        recentLogs: safeLogs,
        newAllergen: AllergenCatalog.sesame,
        candidateDate: now,
      );
      expect(canIntroduceAfterWait, isTrue);
    });

    test('aggregates exposure logs into accurate clinical introduction summaries', () {
      final now = DateTime(2026, 10, 4);

      final logs = [
        // Peanut: 3 safe exposures -> toleratedSafely
        InfantAllergenLog(
          id: 'p-1',
          memberId: 'baby-1',
          allergen: AllergenCatalog.peanuts,
          foodDescription: 'Thinned peanut butter 1/4 tsp',
          exposureDate: now.subtract(const Duration(days: 7)),
          portionGrams: 1.2,
          dayOfProtocol: 1,
        ),
        InfantAllergenLog(
          id: 'p-2',
          memberId: 'baby-1',
          allergen: AllergenCatalog.peanuts,
          foodDescription: 'Thinned peanut butter 1/2 tsp',
          exposureDate: now.subtract(const Duration(days: 5)),
          portionGrams: 2.5,
          dayOfProtocol: 2,
        ),
        InfantAllergenLog(
          id: 'p-3',
          memberId: 'baby-1',
          allergen: AllergenCatalog.peanuts,
          foodDescription: 'Thinned peanut butter 1 tsp',
          exposureDate: now.subtract(const Duration(days: 2)),
          portionGrams: 5.0,
          dayOfProtocol: 3,
        ),
        // Egg: 1 exposure with mild reaction -> adverseReaction
        InfantAllergenLog(
          id: 'e-1',
          memberId: 'baby-1',
          allergen: AllergenCatalog.eggs,
          foodDescription: 'Hard boiled egg yolk puree',
          exposureDate: now.subtract(const Duration(days: 1)),
          portionGrams: 2.0,
          dayOfProtocol: 1,
          reactionSeverity: ReactionSeverity.mild,
          reactionSymptoms: 'Flushed cheeks and mild rash',
        ),
      ];

      final summaries = InfantAllergenEngine.aggregateSummaries(logs: logs);

      expect(summaries[AllergenCatalog.peanuts]?.status, equals(InfantIntroductionStatus.toleratedSafely));
      expect(summaries[AllergenCatalog.peanuts]?.totalExposures, equals(3));
      expect(summaries[AllergenCatalog.peanuts]?.worstReaction, equals(ReactionSeverity.none));

      expect(summaries[AllergenCatalog.eggs]?.status, equals(InfantIntroductionStatus.adverseReaction));
      expect(summaries[AllergenCatalog.eggs]?.totalExposures, equals(1));
      expect(summaries[AllergenCatalog.eggs]?.worstReaction, equals(ReactionSeverity.mild));

      expect(summaries[AllergenCatalog.sesame]?.status, equals(InfantIntroductionStatus.notIntroduced));
      expect(summaries[AllergenCatalog.sesame]?.totalExposures, equals(0));
    });
  });
}
