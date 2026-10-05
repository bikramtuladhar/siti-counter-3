import 'package:kitchen_engine/kitchen_engine.dart';
import 'package:test/test.dart';

void main() {
  group('OcrReceiptParser - Bhatbhateni Supermarket', () {
    test('parses items, units, and amounts from Bhatbhateni receipt', () {
      const receiptText = '''
        BHATBHATENI SUPERMARKET
        KOTESHWOR, KATHMANDU
        PAN NO: 300054321
        DATE: 2026-03-24
        --------------------------------
        POTATO RED 1.5 KG      Rs 97.50
        BBSM MUSTARD OIL 1L    Rs 320.00
        TOMATO LOCAL 500G      Rs 45.00
        CAULIFLOWER 1 PC       Rs 80.00
        --------------------------------
        TOTAL:                 Rs 542.50
        CASH:                  Rs 600.00
        CHANGE:                Rs 57.50
        THANK YOU VISIT AGAIN
      ''';

      final parsed = OcrReceiptParser.parseReceipt(receiptText);

      expect(parsed.merchantName, 'Bhatbhateni Supermarket');
      expect(parsed.receiptDate, '2026-03-24');
      expect(parsed.currency, 'NPR');
      expect(parsed.totalAmount, 542.50);
      expect(parsed.items.length, 4);

      final potato = parsed.items.firstWhere((i) => i.matchedIngredientId == 'potato');
      expect(potato.quantityGrams, 1500.0);
      expect(potato.price, 97.50);

      final oil = parsed.items.firstWhere((i) => i.matchedIngredientId == 'mustard_oil');
      expect(oil.quantityGrams, 1000.0);
      expect(oil.price, 320.00);

      final tomato = parsed.items.firstWhere((i) => i.matchedIngredientId == 'tomato');
      expect(tomato.quantityGrams, 500.0);
      expect(tomato.price, 45.00);
    });
  });

  group('OcrReceiptParser - Local Haat Bazaar & Kirana Nepali bill', () {
    test('parses Devanagari numerals, local units (धार्नी, पाउ), and total', () {
      const kiranaText = '''
        कृषि बजार / हाट बजार रसिद
        मिति: 2026/04/10
        आलु १ धार्नी @ रु १२५      रु 125.00
        गोलभेडा २ पाउ            रु 40.00
        प्याज १ के.जी.            रु 75.00
        --------------------------------
        जम्मा रकम:               रु 240.00
      ''';

      final parsed = OcrReceiptParser.parseReceipt(kiranaText);

      expect(parsed.merchantName, 'Haat Bazaar Bill');
      expect(parsed.receiptDate, '2026/04/10');
      expect(parsed.items.length, 3);

      // 1 Dharni = 2500 grams
      final alu = parsed.items.firstWhere((i) => i.matchedIngredientId == 'potato');
      expect(alu.quantityGrams, 2500.0);
      expect(alu.price, 125.00);

      // 2 Pau = 500 grams
      final tomato = parsed.items.firstWhere((i) => i.matchedIngredientId == 'tomato');
      expect(tomato.quantityGrams, 500.0);
      expect(tomato.price, 40.00);
    });
  });

  group('FoodLabelScanner - Allergen & Cross-contact Detection', () {
    test('detects contains vs may-contain and alerts on severe member allergies', () {
      const labelText = '''
        Ingredients: Refined wheat flour (Maida 68%), Sugar, Edible Vegetable Oil (Palm),
        Milk solids (4%), Salt, Emulsifiers (Soy lecithin).
        Allergy Information: Contains Gluten, Milk and Soy.
        May contain traces of Peanuts and Tree Nuts. Processed on shared equipment.
      ''';

      const household = [
        HouseholdMemberAllergyInput(
          memberId: 'm1',
          memberName: 'Aayush',
          allergen: AllergenCatalog.peanuts,
          severity: AllergySeverity.severe,
        ),
        HouseholdMemberAllergyInput(
          memberId: 'm2',
          memberName: 'Sita',
          allergen: AllergenCatalog.milk,
          severity: AllergySeverity.mild,
        ),
      ];

      final result = FoodLabelScanner.scanLabel(labelText, householdMembers: household);

      expect(result.detectedAllergens, contains(AllergenCatalog.gluten));
      expect(result.detectedAllergens, contains(AllergenCatalog.milk));
      expect(result.detectedAllergens, contains(AllergenCatalog.soy));
      expect(result.facilityWarnings, contains(AllergenCatalog.peanuts));
      expect(result.facilityWarnings, contains(AllergenCatalog.nuts));

      // Neither Aayush (severe peanut in traces) nor Sita (milk in contains) can consider this safe
      expect(result.isSafeForHousehold, isFalse);
      expect(result.memberAlerts.length, 2);

      final aayushAlert = result.memberAlerts.firstWhere((a) => a.memberId == 'm1');
      expect(aayushAlert.warningType, AllergenWarningType.mayContain);
      expect(aayushAlert.alertEn, contains('CAUTION'));
      expect(aayushAlert.alertNe, contains('सावधानी'));

      final sitaAlert = result.memberAlerts.firstWhere((a) => a.memberId == 'm2');
      expect(sitaAlert.warningType, AllergenWarningType.contains);
      expect(sitaAlert.alertEn, contains('DANGER'));
      expect(sitaAlert.alertNe, contains('खतरा'));

      // Highlight spans verify character offsets
      expect(result.highlightSpans, isNotEmpty);
      for (final span in result.highlightSpans) {
        final extracted = labelText.substring(span.start, span.end);
        expect(extracted.toLowerCase(), span.matchedText.toLowerCase());
      }
    });

    test('safe when household has no matching allergens', () {
      const labelText = 'Ingredients: Rice flour, Sugar, Water, Salt.';
      const household = [
        HouseholdMemberAllergyInput(
          memberId: 'm1',
          memberName: 'Aayush',
          allergen: AllergenCatalog.peanuts,
          severity: AllergySeverity.severe,
        ),
      ];

      final result = FoodLabelScanner.scanLabel(labelText, householdMembers: household);
      expect(result.isSafeForHousehold, isTrue);
      expect(result.memberAlerts, isEmpty);
      expect(result.detectedAllergens, isEmpty);
    });
  });
}
