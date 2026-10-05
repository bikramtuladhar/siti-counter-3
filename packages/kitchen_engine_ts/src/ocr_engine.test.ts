import test from 'node:test';
import assert from 'node:assert/strict';
import {
  OcrReceiptParser,
  FoodLabelScanner,
  HouseholdMemberAllergyInput,
} from './ocr_engine.js';
import { AllergenCatalog } from './allergen_engine.js';

test('OcrReceiptParser - Bhatbhateni supermarket receipt parsing', () => {
  const receiptText = `
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
  `;

  const parsed = OcrReceiptParser.parseReceipt(receiptText);

  assert.equal(parsed.merchantName, 'Bhatbhateni Supermarket');
  assert.equal(parsed.receiptDate, '2026-03-24');
  assert.equal(parsed.currency, 'NPR');
  assert.equal(parsed.totalAmount, 542.5);
  assert.equal(parsed.items.length, 4);

  // Item 1: Potato
  const potato = parsed.items.find((i) => i.matchedIngredientId === 'potato');
  assert.ok(potato);
  assert.equal(potato.quantityGrams, 1500);
  assert.equal(potato.price, 97.5);

  // Item 2: Mustard Oil
  const oil = parsed.items.find((i) => i.matchedIngredientId === 'mustard_oil');
  assert.ok(oil);
  assert.equal(oil.quantityGrams, 1000);
  assert.equal(oil.price, 320.0);

  // Item 3: Tomato
  const tomato = parsed.items.find((i) => i.matchedIngredientId === 'tomato');
  assert.ok(tomato);
  assert.equal(tomato.quantityGrams, 500);
  assert.equal(tomato.price, 45.0);
});

test('OcrReceiptParser - Local Haat Bazaar & Kirana Nepali bill parsing', () => {
  const kiranaText = `
    कृषि बजार / हाट बजार रसिद
    मिति: 2026/04/10
    आलु १ धार्नी @ रु १२५      रु 125.00
    गोलभेडा २ पाउ            रु 40.00
    प्याज १ के.जी.            रु 75.00
    --------------------------------
    जम्मा रकम:               रु 240.00
  `;

  const parsed = OcrReceiptParser.parseReceipt(kiranaText);

  assert.equal(parsed.merchantName, 'Haat Bazaar Bill');
  assert.equal(parsed.receiptDate, '2026/04/10');
  assert.equal(parsed.items.length, 3);

  // 1 Dharni = 2500 grams
  const alu = parsed.items.find((i) => i.matchedIngredientId === 'potato');
  assert.ok(alu);
  assert.equal(alu.quantityGrams, 2500);
  assert.equal(alu.price, 125.0);

  // 2 Pau = 500 grams
  const tomato = parsed.items.find((i) => i.matchedIngredientId === 'tomato');
  assert.ok(tomato);
  assert.equal(tomato.quantityGrams, 500);
  assert.equal(tomato.price, 40.0);
});

test('FoodLabelScanner - Detects allergens and cross-contact warnings', () => {
  const labelText = `
    Ingredients: Refined wheat flour (Maida 68%), Sugar, Edible Vegetable Oil (Palm),
    Milk solids (4%), Salt, Emulsifiers (Soy lecithin).
    Allergy Information: Contains Gluten, Milk and Soy.
    May contain traces of Peanuts and Tree Nuts. Processed on shared equipment.
  `;

  const household: HouseholdMemberAllergyInput[] = [
    {
      memberId: 'm1',
      memberName: 'Aayush',
      allergen: AllergenCatalog.peanuts,
      severity: 'severe',
    },
    {
      memberId: 'm2',
      memberName: 'Sita',
      allergen: AllergenCatalog.milk,
      severity: 'mild',
    },
  ];

  const result = FoodLabelScanner.scanLabel(labelText, household);

  assert.ok(result.detectedAllergens.includes(AllergenCatalog.gluten));
  assert.ok(result.detectedAllergens.includes(AllergenCatalog.milk));
  assert.ok(result.detectedAllergens.includes(AllergenCatalog.soy));
  assert.ok(result.facilityWarnings.includes(AllergenCatalog.peanuts));
  assert.ok(result.facilityWarnings.includes(AllergenCatalog.nuts));

  // Aayush has severe peanut allergy and peanuts are in "May contain" -> Not safe
  // Sita has mild milk allergy and milk is in "Contains" -> Not safe
  assert.equal(result.isSafeForHousehold, false);
  assert.equal(result.memberAlerts.length, 2);

  const aayushAlert = result.memberAlerts.find((a) => a.memberId === 'm1');
  assert.ok(aayushAlert);
  assert.equal(aayushAlert.warningType, 'may_contain');
  assert.ok(aayushAlert.alertEn.includes('CAUTION'));
  assert.ok(aayushAlert.alertNe.includes('सावधानी'));

  const sitaAlert = result.memberAlerts.find((a) => a.memberId === 'm2');
  assert.ok(sitaAlert);
  assert.equal(sitaAlert.warningType, 'contains');
  assert.ok(sitaAlert.alertEn.includes('DANGER'));
  assert.ok(sitaAlert.alertNe.includes('खतरा'));

  // Highlight spans verify substring offsets
  assert.ok(result.highlightSpans.length > 0);
  for (const span of result.highlightSpans) {
    const extracted = labelText.substring(span.start, span.end);
    assert.equal(extracted.toLowerCase(), span.matchedText.toLowerCase());
  }
});

test('FoodLabelScanner - Safe when household has no matching allergies', () => {
  const labelText = 'Ingredients: Rice flour, Sugar, Water, Salt.';
  const household: HouseholdMemberAllergyInput[] = [
    {
      memberId: 'm1',
      memberName: 'Aayush',
      allergen: AllergenCatalog.peanuts,
      severity: 'severe',
    },
  ];

  const result = FoodLabelScanner.scanLabel(labelText, household);
  assert.equal(result.isSafeForHousehold, true);
  assert.equal(result.memberAlerts.length, 0);
  assert.equal(result.detectedAllergens.length, 0);
});
