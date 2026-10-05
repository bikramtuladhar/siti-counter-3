import test from 'node:test';
import assert from 'node:assert/strict';
import {
  MultiDishKitchenEngine,
  CookingLane,
} from './multi_dish_kitchen_engine.js';

test('MultiDishKitchenEngine - Parallel cooking lanes management', () => {
  const engine = new MultiDishKitchenEngine({ maxBurners: 2 });

  const dalLane: CookingLane = {
    id: 'lane_dal',
    dishName: 'Kalo Dal',
    dishNameNe: 'कालो दाल',
    vesselType: 'pressure_cooker_3l',
    vesselId: 'pc_3l',
    requiresBurner: true,
    burnerIndex: 1,
    status: 'cooking',
    isAcousticCooker: true,
    currentWhistles: 1,
    targetWhistles: 3,
    remainingSeconds: 0,
    totalSeconds: 0,
    heatLevel: 'medium',
  };

  const riceLane: CookingLane = {
    id: 'lane_rice',
    dishName: 'Basmati Bhat',
    dishNameNe: 'बासमती भात',
    vesselType: 'saucepan',
    vesselId: 'pot_rice',
    requiresBurner: true,
    burnerIndex: 2,
    status: 'cooking',
    isAcousticCooker: false,
    currentWhistles: 0,
    targetWhistles: 0,
    remainingSeconds: 510, // 8m 30s
    totalSeconds: 600,
    heatLevel: 'low',
  };

  const sabziLane: CookingLane = {
    id: 'lane_sabzi',
    dishName: 'Aloo Cauli',
    dishNameNe: 'आलु काउली',
    vesselType: 'kadai_pan',
    vesselId: 'kadai_iron',
    requiresBurner: true,
    status: 'waiting',
    isAcousticCooker: false,
    currentWhistles: 0,
    targetWhistles: 0,
    remainingSeconds: 250, // 4m 10s
    totalSeconds: 400,
    heatLevel: 'off',
  };

  const chapatiLane: CookingLane = {
    id: 'lane_chapati',
    dishName: 'Gahu Chapati',
    dishNameNe: 'गहुँको रोटी',
    vesselType: 'tawa',
    vesselId: 'tawa_iron',
    requiresBurner: true,
    status: 'waiting',
    isAcousticCooker: false,
    currentWhistles: 0,
    targetWhistles: 0,
    remainingSeconds: 0,
    totalSeconds: 0,
    heatLevel: 'off',
  };

  engine.addLane(dalLane);
  engine.addLane(riceLane);
  engine.addLane(sabziLane);
  engine.addLane(chapatiLane);

  assert.equal(engine.getLanes().length, 4);

  // No conflict while 2 are cooking and 2 are waiting
  let conflicts = engine.detectConflicts();
  assert.equal(conflicts.length, 0);

  // Timer ticking
  engine.tickTimers(10);
  assert.equal(engine.getLane('lane_rice')?.remainingSeconds, 500);

  // Single acoustic cooker whistle increments immediately
  const whistleResult = engine.handleAcousticWhistle();
  assert.equal(whistleResult.needsDisambiguation, false);
  assert.equal(whistleResult.attributedLaneId, 'lane_dal');
  assert.equal(engine.getLane('lane_dal')?.currentWhistles, 2);
});

test('MultiDishKitchenEngine - Burner capacity conflict warning (>2 dishes active on 2 burners)', () => {
  const engine = new MultiDishKitchenEngine({ maxBurners: 2 });

  engine.addLane({
    id: 'lane_1',
    dishName: 'Dal',
    dishNameNe: 'दाल',
    vesselType: 'pressure_cooker_3l',
    vesselId: 'v1',
    requiresBurner: true,
    status: 'cooking',
    isAcousticCooker: true,
    currentWhistles: 0,
    targetWhistles: 2,
    remainingSeconds: 0,
    totalSeconds: 0,
    heatLevel: 'high',
  });

  engine.addLane({
    id: 'lane_2',
    dishName: 'Rice',
    dishNameNe: 'भात',
    vesselType: 'saucepan',
    vesselId: 'v2',
    requiresBurner: true,
    status: 'cooking',
    isAcousticCooker: false,
    currentWhistles: 0,
    targetWhistles: 0,
    remainingSeconds: 300,
    totalSeconds: 300,
    heatLevel: 'medium',
  });

  engine.addLane({
    id: 'lane_3',
    dishName: 'Tarkari',
    dishNameNe: 'तरकारी',
    vesselType: 'kadai_pan',
    vesselId: 'v3',
    requiresBurner: true,
    status: 'cooking', // 3rd dish simultaneously trying to cook on 2-burner stove!
    isAcousticCooker: false,
    currentWhistles: 0,
    targetWhistles: 0,
    remainingSeconds: 200,
    totalSeconds: 200,
    heatLevel: 'medium',
  });

  const conflicts = engine.detectConflicts();
  assert.equal(conflicts.length, 1);
  assert.equal(conflicts[0].type, 'burner_capacity');
  assert.ok(conflicts[0].messageEn.includes('Cooktop capacity exceeded: 3 dishes active on 2 burners'));
  assert.ok(conflicts[0].suggestionEn.includes('Move 1 dish(es) to waiting status'));
});

test('MultiDishKitchenEngine - Vessel collision conflict warning', () => {
  const engine = new MultiDishKitchenEngine({ maxBurners: 3 });

  // Both Dal and Chana assigned to the same 5L pressure cooker 'pc_5l_only_one'
  engine.addLane({
    id: 'lane_dal',
    dishName: 'Yellow Dal',
    dishNameNe: 'पहेँलो दाल',
    vesselType: 'pressure_cooker_5l',
    vesselId: 'pc_5l_only_one',
    requiresBurner: true,
    status: 'cooking',
    isAcousticCooker: true,
    currentWhistles: 0,
    targetWhistles: 3,
    remainingSeconds: 0,
    totalSeconds: 0,
    heatLevel: 'high',
  });

  engine.addLane({
    id: 'lane_chana',
    dishName: 'Kalo Chana',
    dishNameNe: 'कालो चना',
    vesselType: 'pressure_cooker_5l',
    vesselId: 'pc_5l_only_one', // SAME vessel ID!
    requiresBurner: true,
    status: 'cooking',
    isAcousticCooker: true,
    currentWhistles: 0,
    targetWhistles: 5,
    remainingSeconds: 0,
    totalSeconds: 0,
    heatLevel: 'high',
  });

  const conflicts = engine.detectConflicts();
  const vesselConflict = conflicts.find((c) => c.type === 'vessel_collision');
  assert.ok(vesselConflict);
  assert.ok(vesselConflict.messageEn.includes("Vessel conflict: Multiple dishes (Yellow Dal & Kalo Chana) assigned to the same vessel 'pc_5l_only_one'"));
  assert.ok(vesselConflict.suggestionEn.includes('Assign an alternate pot'));
});

test('MultiDishKitchenEngine - Acoustic whistle disambiguation when multiple cookers active', () => {
  const engine = new MultiDishKitchenEngine({ maxBurners: 2 });

  engine.addLane({
    id: 'lane_dal',
    dishName: 'Dal',
    dishNameNe: 'दाल',
    vesselType: 'pressure_cooker_3l',
    vesselId: 'pc_3l',
    requiresBurner: true,
    status: 'cooking',
    isAcousticCooker: true,
    currentWhistles: 1,
    targetWhistles: 3,
    remainingSeconds: 0,
    totalSeconds: 0,
    heatLevel: 'high',
  });

  engine.addLane({
    id: 'lane_meat',
    dishName: 'Khasi ko Masu',
    dishNameNe: 'खसीको मासु',
    vesselType: 'pressure_cooker_5l',
    vesselId: 'pc_5l',
    requiresBurner: true,
    status: 'cooking',
    isAcousticCooker: true,
    currentWhistles: 4,
    targetWhistles: 7,
    remainingSeconds: 0,
    totalSeconds: 0,
    heatLevel: 'high',
  });

  // Whistle is detected in the kitchen while BOTH Dal and Meat are actively pressure cooking!
  const whistleResult = engine.handleAcousticWhistle();
  assert.equal(whistleResult.needsDisambiguation, true);
  assert.ok(whistleResult.disambiguationRequest);
  assert.deepEqual(whistleResult.disambiguationRequest?.candidateLaneIds, ['lane_dal', 'lane_meat']);
  assert.deepEqual(whistleResult.disambiguationRequest?.candidateDishNames, ['Dal', 'Khasi ko Masu']);

  assert.ok(engine.getPendingDisambiguation());

  // Cook disambiguates: "That whistle was for the meat cooker!"
  const resolved = engine.resolveDisambiguation('lane_meat');
  assert.equal(resolved, true);
  assert.equal(engine.getLane('lane_meat')?.currentWhistles, 5);
  assert.equal(engine.getLane('lane_dal')?.currentWhistles, 1); // dal untouched
  assert.equal(engine.getPendingDisambiguation(), null);
});
