import { test } from 'node:test';
import assert from 'node:assert';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadRegionPackFromDir, validateRegionPack } from './validator.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const NEPAL_DIR = path.resolve(__dirname, '../nepal-bagmati');
const INDIA_DIR = path.resolve(__dirname, '../india-delhi');
const AUS_DIR = path.resolve(__dirname, '../australia-diaspora');
const ANDES_DIR = path.resolve(__dirname, '../andes-lapaz');

test('nepal-bagmati region pack satisfies schema and integrity rules', () => {
  const pack = loadRegionPackFromDir(NEPAL_DIR);

  assert.strictEqual(pack.manifest.id, 'nepal-bagmati');
  assert.strictEqual(pack.manifest.countryCode, 'NP');
  assert.strictEqual(pack.manifest.elevationMeters, 1400);

  const result = validateRegionPack(pack);

  if (result.errors.length > 0) {
    console.error('Validation errors (nepal-bagmati):', result.errors);
  }
  assert.strictEqual(result.valid, true, `Pack must be valid: ${result.errors.join(', ')}`);
  assert.strictEqual(result.stats.recipesCount >= 150, true, `Expected >= 150 recipes, got ${result.stats.recipesCount}`);
  assert.strictEqual(result.stats.ingredientsCount >= 60, true, `Expected >= 60 ingredients, got ${result.stats.ingredientsCount}`);
  assert.strictEqual(result.stats.festivalsCount >= 10, true, `Expected >= 10 festivals, got ${result.stats.festivalsCount}`);
  assert.strictEqual(result.stats.ritusCount, 6, 'Expected 6 Nepali ritus');
});

test('india-delhi region pack satisfies schema, IFCT nutrition and mandi rules', () => {
  const pack = loadRegionPackFromDir(INDIA_DIR);

  assert.strictEqual(pack.manifest.id, 'india-delhi');
  assert.strictEqual(pack.manifest.countryCode, 'IN');
  assert.strictEqual(pack.manifest.elevationMeters, 216);
  assert.strictEqual(pack.manifest.seasonSystem, 'six-ritus');
  assert.ok(pack.manifest.units.market.includes('katori'));

  const result = validateRegionPack(pack);
  if (result.errors.length > 0) {
    console.error('Validation errors (india-delhi):', result.errors);
  }
  assert.strictEqual(result.valid, true, `Pack must be valid: ${result.errors.join(', ')}`);
  assert.ok(result.stats.recipesCount >= 5, 'Should have core North Indian recipes');
  assert.ok(result.stats.ingredientsCount >= 15, 'Should have rich spices, pulses, and aromatics');
  assert.strictEqual(result.stats.ritusCount, 6, 'Expected 6 North Indian ritus');

  // Check pressure cooker recipes
  const pc = pack.recipes.filter(r => r.pressureCooker.enabled);
  assert.ok(pc.length >= 3, 'Expected at least 3 pressure cooker recipes');
});

test('australia-diaspora region pack satisfies Southern seasons and Taste of Home substitutions', () => {
  const pack = loadRegionPackFromDir(AUS_DIR);

  assert.strictEqual(pack.manifest.id, 'australia-diaspora');
  assert.strictEqual(pack.manifest.countryCode, 'AU');
  assert.strictEqual(pack.manifest.seasonSystem, 'four-seasons-southern');

  const result = validateRegionPack(pack);
  if (result.errors.length > 0) {
    console.error('Validation errors (australia-diaspora):', result.errors);
  }
  assert.strictEqual(result.valid, true, `Pack must be valid: ${result.errors.join(', ')}`);
  assert.strictEqual(result.stats.ritusCount, 4, 'Expected 4 Southern seasons');

  // Verify substitutions are present in aliases or descriptions
  const pepperberry = pack.ingredients.find(i => i.id === 'tasmanian_pepperberry');
  assert.ok(pepperberry, 'Tasmanian pepperberry must be present');
  assert.ok(pepperberry.aliases.some(a => a.toLowerCase().includes('timur')));

  const lamb = pack.ingredients.find(i => i.id === 'aussie_lamb');
  assert.ok(lamb, 'Aussie lamb must be present');
  assert.ok(lamb.aliases.some(a => a.toLowerCase().includes('goat')));
});

test('andes-lapaz region pack satisfies 3,600m altitude calibrations and native tubers', () => {
  const pack = loadRegionPackFromDir(ANDES_DIR);

  assert.strictEqual(pack.manifest.id, 'andes-lapaz');
  assert.strictEqual(pack.manifest.countryCode, 'BO');
  assert.strictEqual(pack.manifest.elevationMeters, 3600);

  const result = validateRegionPack(pack);
  if (result.errors.length > 0) {
    console.error('Validation errors (andes-lapaz):', result.errors);
  }
  assert.strictEqual(result.valid, true, `Pack must be valid: ${result.errors.join(', ')}`);

  // Verify altitude elevation calibration on recipes
  for (const r of pack.recipes) {
    assert.strictEqual(r.elevationBand.testedElevationMeters, 3600);
    assert.strictEqual(r.elevationBand.boilingPointCelsius, 87.4);
    assert.ok(r.elevationBand.waterMultiplier >= 1.3, 'Water multiplier must compensate for lower boiling point');
  }

  // Verify chuño and royal quinoa
  const chuno = pack.ingredients.find(i => i.id === 'chuno');
  assert.ok(chuno, 'Chuño must be in ingredients');
  const quinoa = pack.ingredients.find(i => i.id === 'quinoa');
  assert.ok(quinoa, 'Royal Quinoa must be in ingredients');
});
