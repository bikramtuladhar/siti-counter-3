import test from 'node:test';
import assert from 'node:assert/strict';
import {
  PartyPlannerEngine,
  PartyPlanInput,
  PartyMenuItem,
} from './party_planner_engine.js';

test('PartyPlannerEngine - 20-Guest Feast Scaling & T-Minus Timeline (Section 8.7 & 19.5)', () => {
  const menu: PartyMenuItem[] = [
    {
      recipeId: 'khasi_ko_masu',
      nameEn: 'Mutton Curry',
      nameNe: 'खसीको मासु',
      course: 'main',
      prepDurationMinutes: 20,
      cookDurationMinutes: 45,
      marinateMinutes: 60,
      requiredEquipment: ['pressure_cooker_5l'],
      requiredBurners: 1,
      ingredients: [
        { id: 'mutton', nameEn: 'Mutton', nameNe: 'खसीको मासु', baseGrams: 800 },
        { id: 'onion', nameEn: 'Onion', nameNe: 'प्याज', baseGrams: 300 },
      ],
    },
    {
      recipeId: 'jeera_rice',
      nameEn: 'Jeera Rice',
      nameNe: 'जीरा राइस',
      course: 'side',
      prepDurationMinutes: 10,
      cookDurationMinutes: 25,
      requiredEquipment: ['rice_cooker'],
      requiredBurners: 0,
      ingredients: [
        { id: 'rice', nameEn: 'Basmati Rice', nameNe: 'बासमती चामल', baseGrams: 500 },
      ],
    },
    {
      recipeId: 'mohi',
      nameEn: 'Mint Mohi',
      nameNe: 'पुदिना मोही',
      course: 'drink',
      prepDurationMinutes: 15,
      cookDurationMinutes: 0,
      requiredEquipment: ['blender'],
      ingredients: [
        { id: 'yogurt', nameEn: 'Curd / Dahi', nameNe: 'दही', baseGrams: 500 },
      ],
    },
  ];

  const input: PartyPlanInput = {
    titleEn: 'Dashain Family Feast',
    titleNe: 'दशैं पारिवारिक भोज',
    guestCount: 20,
    serveTime: '19:00',
    menuItems: menu,
    availableEquipment: ['pressure_cooker_5l', 'rice_cooker', 'blender'],
    burnerCount: 3,
    coHosts: ['Bikram', 'Sita', 'Aayush'],
  };

  const plan = PartyPlannerEngine.generatePlan(input);

  assert.equal(plan.guestCount, 20);
  assert.equal(plan.scaleFactor, 5.0); // 20 / 4

  // Verify T-Minus tasks exist
  assert.ok(plan.timeline.length >= 4);

  // Mutton tasks: Marinate, Prep, Cook
  const marinateTask = plan.timeline.find((t) => t.id === 'task_khasi_ko_masu_marinate');
  const cookTask = plan.timeline.find((t) => t.id === 'task_khasi_ko_masu_cook');
  assert.ok(marinateTask);
  assert.ok(cookTask);

  // Marinate must happen before cook (larger T-minus means earlier)
  assert.ok(marinateTask.tMinusMinutes > cookTask.tMinusMinutes);

  // Combined Groceries scaled 5x
  const muttonGrocery = plan.combinedGroceries.find((g) => g.ingredientId === 'mutton');
  assert.ok(muttonGrocery);
  assert.equal(muttonGrocery.scaledGrams, 4000); // 800 * 5

  const riceGrocery = plan.combinedGroceries.find((g) => g.ingredientId === 'rice');
  assert.ok(riceGrocery);
  assert.equal(riceGrocery.scaledGrams, 2500); // 500 * 5

  // Co-hosts assigned
  assert.ok(plan.timeline.some((t) => t.assignedCoHost === 'Bikram'));
  assert.ok(plan.timeline.some((t) => t.assignedCoHost === 'Sita'));
});

test('PartyPlannerEngine - Equipment Conflict Detection (Two dishes needing 5L pressure cooker simultaneously)', () => {
  const menu: PartyMenuItem[] = [
    {
      recipeId: 'dal_makhani',
      nameEn: 'Dal Makhani',
      nameNe: 'दाल मखनी',
      course: 'main',
      prepDurationMinutes: 15,
      cookDurationMinutes: 40,
      requiredEquipment: ['pressure_cooker_5l'],
      requiredBurners: 1,
    },
    {
      recipeId: 'aloo_dum',
      nameEn: 'Dum Aloo',
      nameNe: 'दम आलु',
      course: 'main',
      prepDurationMinutes: 15,
      cookDurationMinutes: 35,
      requiredEquipment: ['pressure_cooker_5l'],
      requiredBurners: 1,
    },
  ];

  const input: PartyPlanInput = {
    titleEn: 'Dinner Party',
    titleNe: 'साँझको भोज',
    guestCount: 12,
    serveTime: '19:00',
    menuItems: menu,
    availableEquipment: ['pressure_cooker_5l'],
    burnerCount: 2,
  };

  const plan = PartyPlannerEngine.generatePlan(input);

  // Both mains finish around 18:50 and their 35-40 min cooking windows overlap!
  assert.equal(plan.isFeasibleWithoutConflict, false);
  assert.equal(plan.equipmentConflicts.length, 1);

  const conflict = plan.equipmentConflicts[0];
  assert.equal(conflict.equipmentId, 'pressure_cooker_5l');
  assert.ok(conflict.resolutionSuggestionEn.includes('Stagger preparation'));
  assert.ok(conflict.resolutionSuggestionNe.includes('समय मिलाउनुहोस्'));
});

test('PartyPlannerEngine - Stove Burner Capacity Conflict Detection', () => {
  const menu: PartyMenuItem[] = [
    {
      recipeId: 'dish_1',
      nameEn: 'Dish 1',
      nameNe: 'परिकार १',
      course: 'main',
      prepDurationMinutes: 10,
      cookDurationMinutes: 30,
      requiredEquipment: ['kadai_1'],
      requiredBurners: 2, // Needs double burner or big flame
    },
    {
      recipeId: 'dish_2',
      nameEn: 'Dish 2',
      nameNe: 'परिकार २',
      course: 'main',
      prepDurationMinutes: 10,
      cookDurationMinutes: 30,
      requiredEquipment: ['kadai_2'],
      requiredBurners: 1,
    },
  ];

  const input: PartyPlanInput = {
    titleEn: 'Stove Limit Test',
    titleNe: 'चुल्हो परीक्षण',
    guestCount: 8,
    serveTime: '20:00',
    menuItems: menu,
    availableEquipment: ['kadai_1', 'kadai_2'],
    burnerCount: 2, // Only 2 burners available, but 2+1=3 needed simultaneously
  };

  const plan = PartyPlannerEngine.generatePlan(input);

  assert.equal(plan.isFeasibleWithoutConflict, false);
  assert.equal(plan.burnerConflicts.length, 1);
  assert.ok(plan.burnerConflicts[0].resolutionSuggestionEn.includes('Exceeds 2 cooktop burners'));
});
