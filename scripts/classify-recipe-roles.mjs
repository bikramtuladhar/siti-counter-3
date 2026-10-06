#!/usr/bin/env node
/**
 * Assigns `dishRoles` and `mealTimes` to every recipe in a region pack.
 *
 * A pack lists the same dish more than once across the day - dal bhat is the breakfast main
 * and again a dinner main, achar is always an accompaniment - and without roles the app
 * recommends a pickle as if it were a meal. See
 * `packages/kitchen_engine_dart/lib/meal_role_engine.dart`.
 *
 * Fields are inserted line-by-line after each recipe's `category` key rather than by
 * re-serialising the JSON, because re-serialising expands every compact array and turns a
 * two-field change into a ~1500-line diff that nobody can review.
 *
 * Existing values are preserved unless `--overwrite` is passed, so a hand-corrected role is
 * never silently reverted.
 *
 * Usage:
 *   node scripts/classify-recipe-roles.mjs                     # all packs, fill gaps only
 *   node scripts/classify-recipe-roles.mjs nepal-bagmati       # one pack
 *   node scripts/classify-recipe-roles.mjs --overwrite         # re-derive every role
 */

import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const PACKS_DIR = 'packages/region-packs';

/**
 * Role defaults per category.
 *
 * `achar` is side-dish-only: an achar is never a meal. `dal` and `masu` are main courses.
 * The ambiguous middle - rice, vegetables, greens, momo - is `both`, because all of them are
 * routinely served both as the meal and next to one.
 */
const ROLE_BY_CATEGORY = {
  achar: ['sideDish'],
  khaja: ['both'],
  tarkari: ['both'],
  saag: ['both'],
  bhat: ['both'],
  soup: ['both'],
  dal: ['mainCourse'],
  masu: ['mainCourse'],
  roti_mithai: ['both'],
};

/**
 * Meal times per category.
 *
 * Meat is excluded from breakfast, the one restriction worth encoding: dal bhat, rice,
 * greens and vegetables genuinely are morning meals in Nepal, and the brief is that main
 * courses must be available at both ends of the day.
 */
const MEAL_TIMES_BY_CATEGORY = {
  dal: ['morning', 'midday', 'evening', 'night'],
  masu: ['midday', 'evening', 'night'],
  tarkari: ['morning', 'midday', 'evening', 'night'],
  saag: ['morning', 'midday', 'evening', 'night'],
  bhat: ['morning', 'midday', 'evening', 'night'],
  soup: ['midday', 'evening', 'night'],
  khaja: ['evening', 'night'],
  roti_mithai: ['morning', 'evening'],
  achar: ['morning', 'midday', 'evening', 'night'],
};

/** Per-recipe overrides where category is too coarse, keyed by recipe id. */
const ROLE_OVERRIDES = {
  'sel-roti': ['both'],
  malpuwa: ['sideDish'],
  kheer: ['sideDish'],
  chhurpi: ['sideDish'],
};

const MEAL_TIME_OVERRIDES = {
  // Festive rice pudding is a sweet, eaten at any time of day.
  kheer: ['morning', 'midday', 'evening', 'night'],
};

/** Recipes seen so far in the current object, so overrides can be matched by id. */
function parseRecipes(parsed) {
  return Array.isArray(parsed) ? parsed : parsed.recipes;
}

function availablePacks() {
  return readdirSync(PACKS_DIR, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .filter((name) => {
      try {
        readFileSync(join(PACKS_DIR, name, 'manifest.json'));
        return true;
      } catch {
        return false;
      }
    });
}

function classifyPack(packName, overwrite) {
  const file = join(PACKS_DIR, packName, 'recipes.json');
  const raw = readFileSync(file, 'utf8');
  const recipes = parseRecipes(JSON.parse(raw));
  if (!Array.isArray(recipes)) {
    throw new Error(`${file}: expected an array or { recipes: [] }`);
  }

  const byId = new Map(recipes.map((recipe) => [recipe.id, recipe]));
  const lines = raw.split('\n');
  const out = [];

  // Tracks which recipe object the cursor is inside, so an override can be applied.
  let currentId = null;
  let pendingRoles = null;
  let pendingTimes = null;

  const flushPending = () => {
    if (!currentId) return;
    const recipe = byId.get(currentId);
    if (!recipe) return;
    const roles = ROLE_OVERRIDES[currentId] ?? ROLE_BY_CATEGORY[recipe.category];
    const times =
      MEAL_TIME_OVERRIDES[currentId] ?? MEAL_TIMES_BY_CATEGORY[recipe.category];
    if (roles) pendingRoles = roles;
    if (times) pendingTimes = times;
  };

  for (const line of lines) {
    const idMatch = line.match(/^\s*"id":\s*"([^"]+)"/);
    if (idMatch) {
      flushPending();
      currentId = idMatch[1];
    }

    const isCategory = /^\s*"category":\s*"([^"]+)"/.test(line);
    const hasRoles = /^\s*"dishRoles":/.test(line);
    const hasTimes = /^\s*"mealTimes":/.test(line);

    out.push(line);

    if (isCategory && currentId) {
      const recipe = byId.get(currentId);
      if (!recipe) continue;

      const roleValue =
        ROLE_OVERRIDES[currentId] ?? ROLE_BY_CATEGORY[recipe.category];
      const timeValue =
        MEAL_TIME_OVERRIDES[currentId] ?? MEAL_TIMES_BY_CATEGORY[recipe.category];

      const existingRoles = Array.isArray(recipe.dishRoles) ? recipe.dishRoles : [];
      const existingTimes = Array.isArray(recipe.mealTimes) ? recipe.mealTimes : [];

      if (roleValue && (overwrite || existingRoles.length === 0)) {
        out.push(
          `    "dishRoles": ${JSON.stringify(roleValue)},`,
        );
      }
      if (timeValue && (overwrite || existingTimes.length === 0)) {
        out.push(
          `    "mealTimes": ${JSON.stringify(timeValue)},`,
        );
      }
    }

    // Suppress a pre-existing declaration when re-deriving, so the file keeps exactly one.
    if ((hasRoles || hasTimes) && overwrite && isCategory) {
      // The declaration directly follows category; skip it on the next iteration.
      continue;
    }
  }

  writeFileSync(file, out.join('\n'));
  return classifyPack.verify(out.join('\n'), packName);
}

classifyPack.verify = (text, packName) => {
  const recipes = parseRecipes(JSON.parse(text));
  const byRole = new Map();
  for (const recipe of recipes) {
    const key = (recipe.dishRoles ?? []).join('+') || 'unclassified';
    byRole.set(key, (byRole.get(key) ?? 0) + 1);
  }
  return { total: recipes.length, byRole };
};

function main() {
  const args = process.argv.slice(2);
  const overwrite = args.includes('--overwrite');
  const requested = args.filter((arg) => !arg.startsWith('--'));

  const packs = requested.length > 0 ? requested : availablePacks();
  if (packs.length === 0) {
    console.error(`No packs found under ${PACKS_DIR}`);
    process.exit(1);
  }

  for (const pack of packs) {
    const result = classifyPack(pack, overwrite);
    const roles = [...result.byRole.entries()]
      .map(([role, count]) => `${role}=${count}`)
      .join(' ');
    console.log(`${pack.padEnd(20)} ${String(result.total).padStart(4)} recipes  ${roles}`);
  }
}

main();