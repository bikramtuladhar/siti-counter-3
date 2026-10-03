import { test } from 'node:test';
import assert from 'node:assert';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadRegionPackFromDir, validateRegionPack } from './validator.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PACK_DIR = path.resolve(__dirname, '../nepal-bagmati');

test('nepal-bagmati region pack satisfies schema and integrity rules', () => {
  const pack = loadRegionPackFromDir(PACK_DIR);

  assert.strictEqual(pack.manifest.id, 'nepal-bagmati');
  assert.strictEqual(pack.manifest.countryCode, 'NP');
  assert.strictEqual(pack.manifest.elevationMeters, 1400);

  const result = validateRegionPack(pack);

  if (result.errors.length > 0) {
    console.error('Validation errors:', result.errors);
  }
  assert.strictEqual(result.valid, true, `Pack must be valid: ${result.errors.join(', ')}`);
  assert.strictEqual(result.stats.recipesCount >= 150, true, `Expected >= 150 recipes, got ${result.stats.recipesCount}`);
  assert.strictEqual(result.stats.ingredientsCount >= 60, true, `Expected >= 60 ingredients, got ${result.stats.ingredientsCount}`);
  assert.strictEqual(result.stats.festivalsCount >= 10, true, `Expected >= 10 festivals, got ${result.stats.festivalsCount}`);
  assert.strictEqual(result.stats.ritusCount, 6, 'Expected 6 Nepali ritus');
});

test('ingredient availability across six ritus is populated', () => {
  const pack = loadRegionPackFromDir(PACK_DIR);
  for (const ing of pack.ingredients) {
    assert.ok(ing.nameEn, `Ingredient ${ing.id} should have English name`);
    assert.ok(ing.nameNe, `Ingredient ${ing.id} should have Nepali name`);
    assert.ok(ing.availability, `Ingredient ${ing.id} should have availability mapping`);
  }
});

test('pressure cooker whistle timings are specified for pressure cooker recipes', () => {
  const pack = loadRegionPackFromDir(PACK_DIR);
  const pcRecipes = pack.recipes.filter(r => r.pressureCooker.enabled);
  assert.ok(pcRecipes.length > 30, 'Should have abundant pressure cooker recipes');

  for (const r of pcRecipes) {
    assert.ok(r.pressureCooker.recommendedWhistles >= 1, `Recipe ${r.id} whistles should be >= 1`);
  }
});
